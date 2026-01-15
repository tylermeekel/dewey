# dewey ☔

A Gleam Meilisearch API client. 

**Note: dewey has not reached version 1.0.0, and is therefore subject to breaking changes. Using this library before the 1.0.0 release means that you understand this message, and are willing to accept any breaking changes that may come.**

[![Package Version](https://img.shields.io/hexpm/v/dewey)](https://hex.pm/packages/dewey)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/dewey/)

This package utilizes a ***sans-io*** approach, meaning http requests are handled by users implementing dewey, instead of dewey coming packaged with an HTTP client. This makes it possible to use dewey across compile targets.


To assist with ease of use, the package makes use of an "Operation" return type for most of its functions.
The Operation type is a tuple of a Request record (from [http/request](https://hexdocs.pm/gleam_http/gleam/http/request.html)), and a function to parse the Response record (from [http/response](https://hexdocs.pm/gleam_http/gleam/http/response.html)) returned from the used HTTP Client.
To see more about this implementation, review the example below. 

```sh
gleam add dewey
```
```gleam
import dewey

pub fn main() -> Nil {
  let meilisearch_url = "..."
  let api_key = "..."
  let assert Ok(client) = dewey.new_client(meilisearch_url, api_key)

  // Destructuring allows us to easily get the Request and Parser out of the Operation record
  let #(request, parse_response) = dewey.get_all_indexes(client)

  // For example when using the httpc client to send requests
  let http_result = httpc.send(request)

  // Handle the http_result...
  let http_response = ...

  let parse_result = parse_response(http_response)

  // ...
}
```

Further documentation can be found at <https://hexdocs.pm/dewey>.

## Features
### Completed Features
- Indexes
- Documents
- Tasks
  - Most features completed
- Search
  - Most features completed

### In Progress Features
- Tasks
  - Proper parsing of Settings Update task details
- Search
  - Final search parameters

### Planned Features
- Network
- Similar Documents
- Facet search
- Chats
- Batches
- Keys
- Settings
- Snapshots
- Stats
- Health
- Version
- Dumps
- Metrics
- Logs
- Export
- Webhooks
- Compact