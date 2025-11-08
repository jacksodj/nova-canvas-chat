# Nova Canvas Image Generation Tool for Open WebUI

## Problem Summary

Open WebUI's built-in `/image` command and image generation icon call the `/v1/chat/completions` endpoint, which expects a chat model format with `messages`. However, Nova Canvas is an image generation model that requires the `/v1/images/generations` endpoint with a different API format.

**This is why you see the error**: `"required key [messages] not found"`

## Solution

Use the custom Nova Canvas Tool that properly calls the image generation API.

## Installation Steps

### 1. Copy the Tool to Open WebUI

The tool file is: `nova_canvas_tool.py`

### 2. Install via Open WebUI Admin Interface

1. **Access Admin Panel**:
   - Navigate to http://localhost:8080
   - Click on your profile → Admin Panel

2. **Go to Tools Section**:
   - In the left sidebar, click on "Tools"

3. **Import the Tool**:
   - Click "+ Add Tool" or "Import Tool"
   - Copy and paste the contents of `nova_canvas_tool.py`
   - Click "Save"

### 3. Enable the Tool

1. Go to Settings → Tools
2. Find "Nova Canvas Image Generator"
3. Enable it for your workspace/users

## Usage

Once installed, you can generate images by:

### Method 1: Direct Tool Call
```
Generate an image of a sunset over mountains
```

The tool will automatically be invoked when appropriate.

### Method 2: Explicit Tool Usage (if configured)
Check the tool's configuration in Open WebUI for specific invocation syntax.

## How It Works

This custom tool:
1. Receives your image prompt
2. Calls the **correct** endpoint: `POST /v1/images/generations`
3. Sends the proper payload format for image generation models
4. Returns the generated image directly in the chat

## Why the Built-in /image Command Fails

| Feature | Built-in `/image` | Custom Tool |
|---------|------------------|-------------|
| Endpoint | `/v1/chat/completions` ❌ | `/v1/images/generations` ✅ |
| Payload format | Chat format (messages) | Image format (prompt) |
| Works with Nova Canvas | No | Yes |
| Streaming issues | Yes | No |

## Configuration

The tool uses these environment variables (automatically configured in docker-compose):
- `LITELLM_URL`: http://litellm:4000 (default)
- `LITELLM_API_KEY`: sk-test-1234567890 (default)

No changes needed to your existing setup!

## Alternative: Direct API Usage

If you don't want to use the tool, you can always call the API directly:

```bash
curl -X POST http://localhost:4000/v1/images/generations \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-test-1234567890' \
  -d '{
    "model": "nova-canvas",
    "prompt": "sunset over mountains",
    "n": 1
  }'
```

This will work perfectly because it uses the correct endpoint.
