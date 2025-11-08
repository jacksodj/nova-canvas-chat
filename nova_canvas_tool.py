"""
title: Nova Canvas Image Generator
author: Claude
version: 1.0.0
description: Generate images using Amazon Nova Canvas through LiteLLM
"""

import requests
import os
from typing import Callable, Any


class Tools:
    def __init__(self):
        self.litellm_url = os.getenv("LITELLM_URL", "http://litellm:4000")
        self.api_key = os.getenv("LITELLM_API_KEY", "sk-test-1234567890")

    def generate_image(
        self, prompt: str, __event_emitter__: Callable[[dict], Any] = None
    ) -> str:
        """
        Generate an image using Nova Canvas
        :param prompt: Description of the image to generate
        :return: Generated image as base64 or URL
        """
        if __event_emitter__:
            __event_emitter__(
                {
                    "type": "status",
                    "data": {"description": "Generating image with Nova Canvas...", "done": False},
                }
            )

        try:
            # Call the proper image generation endpoint
            response = requests.post(
                f"{self.litellm_url}/v1/images/generations",
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {self.api_key}",
                },
                json={
                    "model": "nova-canvas",
                    "prompt": prompt,
                    "n": 1,
                },
                timeout=30,
            )

            response.raise_for_status()
            result = response.json()

            # Extract the image URL or base64
            if "data" in result and len(result["data"]) > 0:
                image_data = result["data"][0]

                if "url" in image_data:
                    image_url = image_data["url"]
                    if __event_emitter__:
                        __event_emitter__(
                            {
                                "type": "status",
                                "data": {"description": "Image generated successfully!", "done": True},
                            }
                        )
                        __event_emitter__(
                            {
                                "type": "message",
                                "data": {"content": f"![Generated Image]({image_url})"},
                            }
                        )
                    return f"Image generated: {image_url}"

                elif "b64_json" in image_data:
                    b64_data = image_data["b64_json"]
                    data_uri = f"data:image/png;base64,{b64_data}"
                    if __event_emitter__:
                        __event_emitter__(
                            {
                                "type": "status",
                                "data": {"description": "Image generated successfully!", "done": True},
                            }
                        )
                        __event_emitter__(
                            {
                                "type": "message",
                                "data": {"content": f"![Generated Image]({data_uri})"},
                            }
                        )
                    return f"Image generated successfully"

            raise ValueError("No image data in response")

        except requests.exceptions.RequestException as e:
            error_msg = f"Error generating image: {str(e)}"
            if __event_emitter__:
                __event_emitter__(
                    {
                        "type": "status",
                        "data": {"description": error_msg, "done": True},
                    }
                )
            return error_msg
