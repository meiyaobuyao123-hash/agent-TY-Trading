"""Async multi-model AI caller — Claude + GPT-4o + Gemini in parallel."""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Optional

import httpx

from backend.config import settings

logger = logging.getLogger(__name__)


async def _call_claude(prompt: str, system: str = "") -> Optional[dict]:
    """Call Anthropic Claude API."""
    if not settings.ANTHROPIC_API_KEY:
        logger.warning("ANTHROPIC_API_KEY not set — skipping Claude")
        return None
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": settings.ANTHROPIC_API_KEY,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json={
                    "model": "claude-sonnet-4-20250514",
                    "max_tokens": 1024,
                    "system": system,
                    "messages": [{"role": "user", "content": prompt}],
                },
            )
            resp.raise_for_status()
            data = resp.json()
            text = data["content"][0]["text"]
            return _parse_json_response(text, "claude")
    except Exception:
        logger.exception("Claude API call failed")
        return None


async def _call_openai(prompt: str, system: str = "") -> Optional[dict]:
    """Call OpenAI GPT-4o API."""
    if not settings.OPENAI_API_KEY:
        logger.warning("OPENAI_API_KEY not set — skipping GPT-4o")
        return None
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            messages = []
            if system:
                messages.append({"role": "system", "content": system})
            messages.append({"role": "user", "content": prompt})
            resp = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.OPENAI_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "gpt-4o",
                    "messages": messages,
                    "max_tokens": 1024,
                    "temperature": 0.3,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            text = data["choices"][0]["message"]["content"]
            return _parse_json_response(text, "gpt-4o")
    except Exception:
        logger.exception("OpenAI API call failed")
        return None


async def _call_gemini(prompt: str, system: str = "") -> Optional[dict]:
    """Call Google Gemini API."""
    if not settings.GOOGLE_API_KEY:
        logger.warning("GOOGLE_API_KEY not set — skipping Gemini")
        return None
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            full_prompt = f"{system}\n\n{prompt}" if system else prompt
            resp = await client.post(
                f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={settings.GOOGLE_API_KEY}",
                headers={"Content-Type": "application/json"},
                json={
                    "contents": [{"parts": [{"text": full_prompt}]}],
                    "generationConfig": {
                        "maxOutputTokens": 1024,
                        "temperature": 0.3,
                    },
                },
            )
            resp.raise_for_status()
            data = resp.json()
            text = data["candidates"][0]["content"]["parts"][0]["text"]
            return _parse_json_response(text, "gemini")
    except Exception:
        logger.exception("Gemini API call failed")
        return None


def _parse_json_response(text: str, model_name: str) -> Optional[dict]:
    """Extract JSON from an AI model response text."""
    # Try to find JSON block in markdown code fence
    import re
    json_match = re.search(r"```(?:json)?\s*\n?(.*?)\n?```", text, re.DOTALL)
    if json_match:
        text = json_match.group(1)

    # Try direct JSON parse
    try:
        parsed = json.loads(text.strip())
        parsed["_model"] = model_name
        return parsed
    except json.JSONDecodeError:
        logger.warning("Failed to parse JSON from %s response", model_name)
        # Return a best-effort dict with the raw text
        return {
            "_model": model_name,
            "direction": "flat",
            "confidence": 0.3,
            "rational_price": None,
            "reasoning": text[:500],
        }


async def _call_deepseek(prompt: str, system: str = "") -> Optional[dict]:
    """Call DeepSeek API (OpenAI-compatible)."""
    if not settings.DEEPSEEK_API_KEY:
        logger.warning("DEEPSEEK_API_KEY not set — skipping DeepSeek")
        return None
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            messages = []
            if system:
                messages.append({"role": "system", "content": system})
            messages.append({"role": "user", "content": prompt})
            resp = await client.post(
                "https://api.deepseek.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.DEEPSEEK_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "deepseek-chat",
                    "messages": messages,
                    "max_tokens": 1024,
                    "temperature": 0.3,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            text = data["choices"][0]["message"]["content"]
            return _parse_json_response(text, "deepseek")
    except Exception:
        logger.exception("DeepSeek API call failed")
        return None


async def call_all_models(prompt: str, system: str = "") -> list[dict]:
    """Call enabled AI models in parallel, return list of non-None results."""
    results = await asyncio.gather(
        _call_deepseek(prompt, system),
        _call_openai(prompt, system),
        _call_gemini(prompt, system),
        return_exceptions=True,
    )
    valid = []
    for r in results:
        if isinstance(r, Exception):
            logger.error("AI model call raised: %s", r)
        elif r is not None:
            valid.append(r)
    return valid
