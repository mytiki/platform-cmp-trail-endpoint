/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

use super::{features::license, utils::ErrorResponse};
use lambda_http::{
    http::{Method, StatusCode},
    Request, RequestExt,
};
use serde::Serialize;
use std::{error::Error, future::Future};

async fn json_body<Fut, T>(
    event: Request,
    route: impl FnOnce(Request) -> Fut,
) -> Result<(StatusCode, String), Box<dyn Error>>
where
    Fut: Future<Output = Result<(StatusCode, T), Box<dyn Error>>>,
    T: Serialize,
{
    let rsp = route(event).await?;
    Ok((rsp.0, serde_json::to_string(&rsp.1)?))
}

pub async fn entry(event: Request) -> Result<(StatusCode, String), Box<dyn Error>> {
    match (event.method(), event.raw_http_path()) {
        (&Method::POST, "/license/create") => json_body(event, license::create).await,
        (&Method::POST, "/license/verify") => json_body(event, license::verify).await,
        _ => Err(ErrorResponse::new(StatusCode::NOT_FOUND).into()),
    }
}
