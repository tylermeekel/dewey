import gleam/dynamic/decode
import gleam/http.{Delete, Get, Patch, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/result
import gleam/time/timestamp.{type Timestamp}

// ----- PUBLIC HELPER TYPES AND FNS -----
pub type ParseResponseFunc(data_type) =
  fn(Response(String)) -> Result(data_type, DeweyError)

pub type DeweyError {
  JSONDecodeError(err: json.DecodeError)
}

// ----- CLIENT -----
pub opaque type Client {
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
) -> #(Request(String), ParseResponseFunc(List(Index))) {
  let url = client.url <> "/indexes"
  let req = base_request(url, client.api_key)

  // Build response parser function
  let parse_response = fn(response: Response(String)) -> Result(
    List(Index),
    DeweyError,
  ) {
    let decoder = {
      use indexes <- decode.field("results", decode.list(index_decoder()))
      decode.success(indexes)
    }

    json.parse(response.body, decoder)
    |> result.map_error(JSONDecodeError)
  }

  #(req, parse_response)
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

// ----- PRIVATE HELPER TYPES AND FNS -----
fn base_request(url: String, api_key: String) -> Request(String) {
  let assert Ok(base_req) = request.to(url)

  request.set_header(base_req, "Authorization", "Bearer " <> api_key)
}
