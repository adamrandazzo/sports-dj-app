# Text-to-Speech API Documentation

REST API documentation for generating AI text-to-speech audio from your iOS application. This is the same base API as the setlist feature

## Endpoint

```
POST https://api.ultimatesportsdj.app/api/v1/dugoutdj/tts
```

## Authentication

Include your API token in the `Authorization` header:

```
Authorization: Bearer (Same as used in the setlists)
```

## Request

### Headers

| Header          | Value              | Required    |
| --------------- | ------------------ | ----------- |
| `Authorization` | `Bearer {token}`   | Yes         |
| `Content-Type`  | `application/json` | Yes         |
| `Accept`        | `audio/mpeg`       | Recommended |

### Body Parameters

| Parameter  | Type   | Required | Description                                                                                 |
| ---------- | ------ | -------- | ------------------------------------------------------------------------------------------- |
| `text`     | string | Yes      | The text to convert to speech (1-5000 characters). Typically a player name or announcement. |
| `voice_id` | string | No       | ElevenLabs voice ID. Falls back to server default if not provided.                          |
| `model_id` | string | No       | ElevenLabs model ID. Defaults to `eleven_multilingual_v2`.                                  |

### Example Request Body

```json
{
  "text": "Mike Trout",
  "voice_id": "21m00Tcm4TlvDq8ikWAM"
}
```

## Response

### Success (200 OK)

Returns binary MP3 audio data.

#### Response Headers

| Header           | Description                                               |
| ---------------- | --------------------------------------------------------- |
| `Content-Type`   | `audio/mpeg`                                              |
| `Content-Length` | Size of the audio file in bytes                           |
| `X-Cached`       | `true` if served from cache, `false` if freshly generated |

#### Response Body

Raw binary MP3 audio data (44.1kHz, 128kbps).

### Error Responses

| Status                     | Description                     |
| -------------------------- | ------------------------------- |
| `401 Unauthorized`         | Invalid or missing API token    |
| `404 Not Found`            | Invalid app or app is inactive  |
| `422 Unprocessable Entity` | Validation error or API failure |
| `503 Service Unavailable`  | TTS service not configured      |

#### Error Response Body

```json
{
  "error": "Error description here"
}
```

## Caching

The API automatically caches generated audio based on the combination of:

- `text` (exact match)
- `voice_id`
- `model_id`

**How it works:**

1. First request with a unique text/voice combination calls the ElevenLabs API and caches the result
2. Subsequent identical requests return the cached audio instantly without calling ElevenLabs
3. Check the `X-Cached` response header to determine if the response was served from cache

**Benefits:**

- Faster response times for repeated announcements
- Reduced API costs
- Consistent audio for the same player names



## Rate Limits

The API may return a `422` status with `"Rate limit exceeded"` if ElevenLabs rate limits are hit. Implement exponential backoff retry logic for production apps.
