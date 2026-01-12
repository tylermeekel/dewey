import gleam/dynamic/decode
import gleam/http.{Delete, Get, Patch, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/result
import gleam/time/timestamp.{type Timestamp}

// ----- HELPER TYPES AND FNS -----
pub type SendRequestFunction(user_error_type) =
  fn(Request(String)) -> Result(Response(String), user_error_type)

pub type Error(user_error_type) {
  CustomError(user_error_type)
  JSONDecodeError(json.DecodeError)
}

// ----- CLIENT -----
pub type Client {
  Client(url: String, api_key: String)
}

pub fn new_client(url: String, api_key: String) -> Result(Client, Nil) {
  // TODO: Check for valid http/https url
  Ok(Client(url:, api_key:))
}

// ----- TASKS -----

// ----- INDEXES -----
pub type Index {
  Index(
    uid: String,
    created_at: Timestamp,
    updated_at: Timestamp,
    primary_key: String,
  )
}

pub fn get_all_indexes(
  client: Client,
  send_req: SendRequestFunction(user_error_type),
) -> Result(List(Index), Error(user_error_type)) {
  let url = client.url <> "/indexes"
  let assert Ok(base_req) = request.to(url)

  let req =
    request.set_method(base_req, Get)
    |> request.set_header("Authorization", "Bearer " <> client.api_key)

  let res =
    send_req(req)
    |> result.map_error(CustomError)

  use resp <- result.try(res)

  let decoder = {
    use indexes <- decode.field("results", decode.list(index_decoder()))
    decode.success(indexes)
  }

  json.parse(resp.body, decoder)
  |> result.map_error(JSONDecodeError)
}

// ------ DOCUMENTS -----

// ----- SEARCH -----

// ----- DECODERS -----
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
