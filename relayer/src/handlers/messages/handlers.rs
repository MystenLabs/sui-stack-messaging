//! HTTP handler functions for message CRUD operations.

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Extension, Json,
};
use uuid::Uuid;

use crate::auth::AuthContext;
use crate::models::{Attachment, Message};
use crate::state::AppState;

use super::error::ApiError;
use super::request::{
    AttachmentRequest, CreateMessageRequest, GetMessagesQuery, UpdateMessageRequest,
};
use super::response::{
    CreateMessageResponse, EmptyResponse, GetMessagesResponse, MessageResponse,
    MessagesListResponse,
};

/// Default number of messages per page
const DEFAULT_PAGE_LIMIT: usize = 50;
/// Maximum allowed messages per page
const MAX_PAGE_LIMIT: usize = 100;

/// POST /messages - Create a new message
pub async fn create_message(
    State(state): State<AppState>,
    Json(req): Json<CreateMessageRequest>,
) -> Result<(StatusCode, Json<CreateMessageResponse>), ApiError> {
    // Decode hex-encoded encrypted text
    let encrypted_msg = hex::decode(&req.encrypted_text)
        .map_err(|e| ApiError::BadRequest(format!("Invalid hex in encrypted_text: {}", e)))?;

    // Decode hex-encoded nonce
    let nonce = hex::decode(&req.nonce)
        .map_err(|e| ApiError::BadRequest(format!("Invalid hex in nonce: {}", e)))?;
    if nonce.len() != 12 {
        return Err(ApiError::BadRequest(format!(
            "Nonce must be exactly 12 bytes, got {}",
            nonce.len()
        )));
    }

    let attachments = decode_attachments(req.attachments)?;

    // Create message domain object
    let message = Message::new(
        req.group_id,
        req.sender_address,
        encrypted_msg,
        nonce,
        req.key_version,
        attachments,
    );

    // Store message
    let created = state.storage.create_message(message).await?;

    // Notify the Walrus sync worker that a new message was created.
    let _ = state.sync_notifier.send(());

    Ok((
        StatusCode::CREATED,
        Json(CreateMessageResponse {
            message_id: created.id,
        }),
    ))
}

/// GET /messages - Get single message or paginated list
pub async fn get_messages(
    State(state): State<AppState>,
    Query(query): Query<GetMessagesQuery>,
) -> Result<Json<GetMessagesResponse>, ApiError> {
    // If message_id is provided, return single message
    if let Some(message_id) = query.message_id {
        let message = state.storage.get_message(message_id).await?;
        let response: MessageResponse = message.into();
        return Ok(Json(GetMessagesResponse::Single(response)));
    }

    // Otherwise, require group_id for paginated list
    let group_id = query
        .group_id
        .ok_or_else(|| ApiError::BadRequest("Either message_id or group_id is required".into()))?;

    let limit = query
        .limit
        .unwrap_or(DEFAULT_PAGE_LIMIT)
        .min(MAX_PAGE_LIMIT);

    // Fetch one extra to determine hasNext
    let messages = state
        .storage
        .get_messages_by_group(&group_id, query.after_order, query.before_order, limit + 1)
        .await?;

    let has_next = messages.len() > limit;
    let messages: Vec<MessageResponse> =
        messages.into_iter().take(limit).map(|m| m.into()).collect();

    let response = MessagesListResponse { messages, has_next };
    Ok(Json(GetMessagesResponse::List(response)))
}

/// PUT /messages - Update a message
/// Only the original message sender can edit their own message.
pub async fn update_message(
    State(state): State<AppState>,
    Json(req): Json<UpdateMessageRequest>,
) -> Result<Json<EmptyResponse>, ApiError> {
    // Fetch existing message to verify ownership
    let existing_message = state.storage.get_message(req.message_id).await?;

    // Only the original sender can edit their message
    if existing_message.sender_wallet_addr != req.sender_address {
        return Err(ApiError::Forbidden(
            "Only the original sender can edit this message".to_string(),
        ));
    }

    // Decode hex-encoded encrypted text
    let encrypted_msg = hex::decode(&req.encrypted_text)
        .map_err(|e| ApiError::BadRequest(format!("Invalid hex in encrypted_text: {}", e)))?;

    // Decode hex-encoded nonce
    let nonce = hex::decode(&req.nonce)
        .map_err(|e| ApiError::BadRequest(format!("Invalid hex in nonce: {}", e)))?;
    if nonce.len() != 12 {
        return Err(ApiError::BadRequest(format!(
            "Nonce must be exactly 12 bytes, got {}",
            nonce.len()
        )));
    }

    let attachments = decode_attachments(req.attachments)?;

    // Update message
    state
        .storage
        .update_message(
            req.message_id,
            encrypted_msg,
            nonce,
            req.key_version,
            attachments,
        )
        .await?;

    Ok(Json(EmptyResponse {}))
}

/// DELETE /messages/:message_id - Soft delete a message
/// Only the original message sender can delete their own message.
pub async fn delete_message(
    State(state): State<AppState>,
    Path(message_id): Path<Uuid>,
    Extension(auth): Extension<AuthContext>,
) -> Result<Json<EmptyResponse>, ApiError> {
    // Fetch existing message to verify ownership
    let existing_message = state.storage.get_message(message_id).await?;

    // Only the original sender can delete their message
    if existing_message.sender_wallet_addr != auth.sender_address {
        return Err(ApiError::Forbidden(
            "Only the original sender can delete this message".to_string(),
        ));
    }

    state.storage.delete_message(message_id).await?;
    Ok(Json(EmptyResponse {}))
}

/// Decodes a list of attachment request DTOs into domain attachments.
fn decode_attachments(requests: Vec<AttachmentRequest>) -> Result<Vec<Attachment>, ApiError> {
    requests
        .into_iter()
        .map(|r| r.try_into_attachment().map_err(ApiError::BadRequest))
        .collect()
}
