import gleam/dynamic/decode
import gleam/http.{Delete, Get, Patch, Post, Put}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None}
import gleam/result
import gleam/time/timestamp.{type Timestamp}

// ----- PUBLIC HELPER TYPES AND FNS -----
pub type ParseResponseFunc(data_type) =
  fn(Response(String)) -> Result(data_type, DeweyError)

pub type DeweyError {
  JSONDecodeError(err: json.DecodeError)
  APIError(message: String, code: String, error_type: String, link: String)

  // This should only occur if the assumption about the shape of the error object is incorrect.
  // The error object type is outlined at: https://www.meilisearch.com/docs/reference/errors/overview
  UnexpectedAPIError
}

pub type Operation(data_type) =
  #(Request(String), ParseResponseFunc(data_type))

// ----- CLIENT -----
pub opaque type Client {
  Client(url: String, api_key: String)
}

pub fn new_client(url: String, api_key: String) -> Result(Client, Nil) {
  // TODO: Check for valid http/https url
  Ok(Client(url:, api_key:))
}

// ----- TASKS -----
pub type SummarizedTask {
  SummarizedTask(
    task_uid: Int,
    index_uid: Option(String),
    status: TaskStatus,
    task_type: TaskType,
    enqueued_at: timestamp.Timestamp,
  )
}

fn parse_summarized_task_response(
  resp: Response(String),
) -> Result(SummarizedTask, DeweyError) {
  use resp_body <- result.try(verify_response(resp))

  json.parse(resp_body, summarized_task_decoder())
  |> result.map_error(JSONDecodeError)
}

pub type Task {
  Task(
    uid: Int,
    index_uid: Option(String),
    status: TaskStatus,
    task_type: TaskType,
    canceled_by: Option(Int),
    details: TaskDetails,
    error: Option(TaskError),
    // TODO: Figure out how to parse an ISO8601 duration
    // duration: duration.Duration,
    enqueued_at: timestamp.Timestamp,
    started_at: timestamp.Timestamp,
    finished_at: timestamp.Timestamp,
  )
}

pub type TaskStatus {
  Enqueued
  Processing
  Succeeded
  Failed
  Canceled

  // This should never happen.
  // https://www.meilisearch.com/docs/reference/api/tasks#status
  UnexpectedTaskStatus
}

fn string_to_task_status(str: String) -> TaskStatus {
  case str {
    "enqueued" -> Enqueued
    "processing" -> Processing
    "succeeded" -> Succeeded
    "failed" -> Failed
    "canceled" -> Canceled
    _ -> UnexpectedTaskStatus
  }
}

pub type TaskType {
  IndexCreation
  IndexUpdate
  IndexDeletion
  IndexSwap
  DocumentAdditionOrUpdate
  DocumentDeletion
  SettingsUpdate
  DumpCreation
  TaskCancelation
  TaskDeletion
  UpgradeDatabase
  DocumentEdition
  SnapshotCreation

  // This should never happen.
  // https://www.meilisearch.com/docs/reference/api/tasks#type
  UnexpectedTaskType
}

fn string_to_task_type(str: String) -> TaskType {
  case str {
    "indexCreation" -> IndexCreation
    "indexUpdate" -> IndexUpdate
    "indexDeletion" -> IndexDeletion
    "indexSwap" -> IndexSwap
    "documentAdditionOrUpdate" -> DocumentAdditionOrUpdate
    "documentDeletion" -> DocumentDeletion
    "settingsUpdate" -> SettingsUpdate
    "dumpCreation" -> DumpCreation
    "taskCancelation" -> TaskCancelation
    "taskDeletion" -> TaskDeletion
    "upgradeDatabase" -> UpgradeDatabase
    "documentEdition" -> DocumentEdition
    "snapshotCreation" -> SnapshotCreation
    _ -> UnexpectedTaskType
  }
}

pub type TaskDetails

pub type TaskError {
  TaskError(message: String, code: String, error_type: String, link: String)
}

// ----- INDEXES -----
pub type Index {
  Index(
    uid: String,
    created_at: Timestamp,
    updated_at: Timestamp,
    primary_key: String,
  )
}

/// Returns an Operation object for the Get All Indexes endpoint
/// 
/// This endpoint is outlined at: https://www.meilisearch.com/docs/reference/api/indexes#list-all-indexes
pub fn get_all_indexes(client: Client) -> Operation(List(Index)) {
  let url = client.url <> "/indexes"

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Get)

  #(req, fn(resp: Response(String)) -> Result(List(Index), DeweyError) {
    use resp_body <- result.try(verify_response(resp))

    let decoder = {
      use indexes <- decode.field("results", decode.list(index_decoder()))
      decode.success(indexes)
    }

    json.parse(resp_body, decoder)
    |> result.map_error(JSONDecodeError)
  })
}

/// Returns an Operation object for the Get One Index endpoint
/// 
/// This endpoint is outlined at: https://www.meilisearch.com/docs/reference/api/indexes#get-one-index
pub fn get_one_index(client: Client, index_uid: String) -> Operation(Index) {
  let url = client.url <> "/indexes/" <> index_uid

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Get)

  #(req, fn(resp: Response(String)) -> Result(Index, DeweyError) {
    use resp_body <- result.try(verify_response(resp))

    json.parse(resp_body, index_decoder())
    |> result.map_error(JSONDecodeError)
  })
}

/// Returns an Operation object for the Create Index endpoint
/// 
/// This endpoint is outlined at: https://www.meilisearch.com/docs/reference/api/indexes#create-an-index
pub fn create_index(
  client: Client,
  index_uid: String,
  primary_key: Option(String),
) -> Operation(SummarizedTask) {
  let url = client.url <> "/indexes"

  let req_body =
    json.object([
      #("uid", json.string(index_uid)),
      #("primaryKey", json.nullable(primary_key, json.string)),
    ])
    |> json.to_string

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(req_body)

  #(req, parse_summarized_task_response)
}

/// Returns an Operation object for the Update Index endpoint
/// 
/// This endpoint is outlined at: https://www.meilisearch.com/docs/reference/api/indexes#update-an-index
pub fn update_index(
  client: Client,
  index_uid: String,
  new_primary_key: Option(String),
) -> Operation(SummarizedTask) {
  let url = client.url <> "/indexes/" <> index_uid

  let req_body =
    json.object([#("primaryKey", json.nullable(new_primary_key, json.string))])
    |> json.to_string

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Patch)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(req_body)

  #(req, parse_summarized_task_response)
}

pub fn delete_index(
  client: Client,
  index_uid: String,
) -> Operation(SummarizedTask) {
  let url = client.url <> "/indexes/" <> index_uid

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Delete)

  #(req, parse_summarized_task_response)
}

/// Returns an Operation object for the Swap Indexes endpoint
/// 
/// This function does not include the rename parameter, and therefore does not rename
/// indexes when the second index does not exist. To rename indexes, use the rename_indexes
/// function instead. 
/// 
/// This endpoint is outlined at: https://www.meilisearch.com/docs/reference/api/indexes#swap-indexes
pub fn swap_indexes(
  client: Client,
  index_uids_to_swap: List(#(String, String)),
) -> Operation(SummarizedTask) {
  let url = client.url <> "/swap-indexes"

  let indexes_list =
    list.map(index_uids_to_swap, fn(tuple) { [tuple.0, tuple.1] })

  let req_body =
    json.array(indexes_list, fn(indexes) {
      json.object([#("indexes", json.array(indexes, json.string))])
    })
    |> json.to_string

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(req_body)

  #(req, parse_summarized_task_response)
}

/// Returns an Operation object for the Swap Indexes endpoint, utilizing the
/// rename parameter.
/// 
/// This function includes the rename parameter within the request body, meaning that
/// the first index_uid will be renamed to the second index_uid listed (assuming the second uid does not exist).
/// 
/// This endpoint is outlined at: https://www.meilisearch.com/docs/reference/api/indexes#swap-indexes
pub fn rename_indexes(
  client: Client,
  index_uids_to_swap: List(#(String, String)),
) -> Operation(SummarizedTask) {
  let url = client.url <> "/swap-indexes"

  let indexes_list =
    list.map(index_uids_to_swap, fn(tuple) { [tuple.0, tuple.1] })

  let req_body =
    json.array(indexes_list, fn(indexes) {
      json.object([
        #("indexes", json.array(indexes, json.string)),
        #("rename", json.bool(True)),
      ])
    })
    |> json.to_string

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(req_body)

  #(req, parse_summarized_task_response)
}

// ------ DOCUMENTS -----
pub type DocumentsResponse(document_type) {
  DocumentsResponse(
    results: List(document_type),
    offset: Int,
    limit: Int,
    total: Int,
  )
}

pub type GetDocumentsOptions {
  GetDocumentsOptions(
    offset: Int,
    limit: Int,
    fields: Option(List(String)),
    filter: Option(String),
    retrieve_vectors: Bool,
    sort: Option(String),
    ids: Option(List(String)),
  )
}

pub fn default_get_documents_options() -> GetDocumentsOptions {
  GetDocumentsOptions(
    offset: 0,
    limit: 20,
    fields: None,
    filter: None,
    retrieve_vectors: False,
    sort: None,
    ids: None,
  )
}

pub fn get_documents(
  client: Client,
  index_uid: String,
  options: GetDocumentsOptions,
  documents_decoder: decode.Decoder(document_type),
) -> Operation(DocumentsResponse(document_type)) {
  let url = client.url <> "/indexes/" <> index_uid <> "/documents/fetch"

  let json_string_array = json.array(_, json.string)

  let req_body =
    json.object([
      #("offset", json.int(options.offset)),
      #("limit", json.int(options.limit)),
      #("fields", json.nullable(options.fields, json_string_array)),
      #("filter", json.nullable(options.filter, json.string)),
      #("retrieveVectors", json.bool(options.retrieve_vectors)),
      #("sort", json.nullable(options.sort, json.string)),
      #("ids", json.nullable(options.ids, json_string_array)),
    ])
    |> json.to_string

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(req_body)

  #(req, fn(resp: Response(String)) -> Result(
    DocumentsResponse(document_type),
    DeweyError,
  ) {
    use resp_body <- result.try(verify_response(resp))

    let decoder = {
      use results <- decode.field("results", decode.list(documents_decoder))
      use offset <- decode.field("offset", decode.int)
      use limit <- decode.field("limit", decode.int)
      use total <- decode.field("total", decode.int)

      decode.success(DocumentsResponse(results:, offset:, limit:, total:))
    }

    json.parse(resp_body, decoder)
    |> result.map_error(JSONDecodeError)
  })
}

pub type DocumentID {
  StringID(id: String)
  IntID(id: Int)
}

pub fn get_one_document(
  client: Client,
  index_uid: String,
  document_id: DocumentID,
  document_decoder: decode.Decoder(document_type),
) -> Operation(document_type) {
  let document_id_string = case document_id {
    StringID(id:) -> id
    IntID(id:) -> int.to_string(id)
  }
  let url =
    client.url
    <> "/indexes/"
    <> index_uid
    <> "/documents/"
    <> document_id_string

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Get)

  #(req, fn(resp: Response(String)) -> Result(document_type, DeweyError) {
    use resp_body <- result.try(verify_response(resp))

    json.parse(resp_body, document_decoder)
    |> result.map_error(JSONDecodeError)
  })
}

pub fn add_or_replace_documents(
  client: Client,
  index_uid: String,
  documents: List(document_type),
  document_encoder: fn(document_type) -> json.Json,
) -> Operation(SummarizedTask) {
  let url = client.url <> "/indexes/" <> index_uid <> "/documents"

  let req_body =
    json.array(documents, document_encoder)
    |> json.to_string

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(req_body)

  #(req, parse_summarized_task_response)
}

pub fn add_or_update_documents(
  client: Client,
  index_uid: String,
  documents: List(document_type),
  document_encoder: fn(document_type) -> json.Json,
) -> Operation(SummarizedTask) {
  let url = client.url <> "/indexes/" <> index_uid <> "/documents"

  let req_body =
    json.array(documents, document_encoder)
    |> json.to_string

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Put)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(req_body)

  #(req, parse_summarized_task_response)
}

pub fn delete_all_documents(
  client: Client,
  index_uid: String,
) -> Operation(SummarizedTask) {
  let url = client.url <> "/indexes/" <> index_uid <> "/documents"

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Delete)

  #(req, parse_summarized_task_response)
}

pub fn delete_one_document(
  client: Client,
  index_uid: String,
  document_id: DocumentID,
) -> Operation(SummarizedTask) {
  let document_id_string = case document_id {
    StringID(id:) -> id
    IntID(id:) -> int.to_string(id)
  }

  let url =
    client.url
    <> "/indexes/"
    <> index_uid
    <> "/documents/"
    <> document_id_string

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Delete)

  #(req, parse_summarized_task_response)
}

pub fn delete_documents_by_filter(
  client: Client,
  index_uid: String,
  filter: String,
) -> Operation(SummarizedTask) {
  let url = client.url <> "/indexes/" <> index_uid <> "/documents/delete"

  let req_body =
    json.object([#("filter", json.string(filter))])
    |> json.to_string

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(req_body)

  #(req, parse_summarized_task_response)
}

pub fn delete_documents_by_batch(
  client: Client,
  index_uid: String,
  batch: List(Int),
) -> Operation(SummarizedTask) {
  let url = client.url <> "/indexes/" <> index_uid <> "/documents/delete-batch"

  let req_body =
    json.array(batch, json.int)
    |> json.to_string

  let req =
    base_request(url, client.api_key)
    |> request.set_method(Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(req_body)

  #(req, parse_summarized_task_response)
}

// ----- SEARCH -----

// ----- DECODERS -----
fn summarized_task_decoder() -> decode.Decoder(SummarizedTask) {
  use task_uid <- decode.field("taskUid", decode.int)
  use index_uid <- decode.field("indexUid", decode.optional(decode.string))
  use status_str <- decode.field("status", decode.string)
  use type_str <- decode.field("type", decode.string)
  use enqueued_at_str <- decode.field("enqueuedAt", decode.string)

  let status = string_to_task_status(status_str)
  let task_type = string_to_task_type(type_str)

  // This should never fail, as the API should always return an RFC3339 string
  // https://www.meilisearch.com/docs/reference/api/tasks#enqueuedat
  let assert Ok(enqueued_at) = timestamp.parse_rfc3339(enqueued_at_str)

  decode.success(SummarizedTask(
    task_uid:,
    index_uid:,
    status:,
    task_type:,
    enqueued_at:,
  ))
}

fn index_decoder() -> decode.Decoder(Index) {
  use uid <- decode.field("uid", decode.string)
  use created_at_string <- decode.field("createdAt", decode.string)
  use updated_at_string <- decode.field("updatedAt", decode.string)
  use primary_key <- decode.field("primaryKey", decode.string)

  let created_at =
    timestamp.parse_rfc3339(created_at_string)
    |> result.unwrap(timestamp.from_unix_seconds(0))

  let updated_at =
    timestamp.parse_rfc3339(updated_at_string)
    |> result.unwrap(timestamp.from_unix_seconds(0))

  decode.success(Index(uid:, created_at:, updated_at:, primary_key:))
}

// ----- PRIVATE HELPER TYPES AND FNS -----
fn base_request(url: String, api_key: String) -> Request(String) {
  let assert Ok(base_req) = request.to(url)

  request.set_header(base_req, "Authorization", "Bearer " <> api_key)
}

const acceptable_response_codes = [200, 201, 202, 204, 205]

fn verify_response(resp: Response(String)) -> Result(String, DeweyError) {
  case list.contains(acceptable_response_codes, resp.status) {
    True -> Ok(resp.body)
    False -> {
      let decoder = {
        use message <- decode.field("message", decode.string)
        use code <- decode.field("code", decode.string)
        use error_type <- decode.field("type", decode.string)
        use link <- decode.field("link", decode.string)

        decode.success(APIError(message:, code:, error_type:, link:))
      }

      case json.parse(resp.body, decoder) {
        Ok(api_error) -> Error(api_error)
        Error(_) -> Error(UnexpectedAPIError)
      }
    }
  }
}
