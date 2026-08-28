import json
import logging
from typing import Optional
from app.core.config import settings

logger = logging.getLogger(__name__)


class AIService:
    """AI service for generating professional insights from transcripts."""

    @staticmethod
    async def generate_insights(transcript: str, session_title: str) -> dict:
        """Generate insights from a transcript using AI."""
        if not settings.OPENAI_API_KEY:
            raise ValueError("OpenAI API key not configured")

        try:
            import openai
            client = openai.AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

            prompt = f"""Analyze this professional {session_title} transcript and extract structured insights.

TRANSCRIPT:
{transcript}

Provide a JSON response with these fields:
{{
    "summary": "2-3 sentence summary of the discussion",
    "vocabulary": ["list of key terms used"],
    "themes": ["main themes discussed"],
    "action_items": ["specific action items mentioned"],
    "deadlines": ["deadlines or dates mentioned"],
    "mentioned_people": ["people mentioned by name or role"]
}}

Rules:
- Be accurate and only extract information actually present in the transcript
- Keep items concise
- If no clear action items or deadlines exist, return empty arrays
- Do not fabricate information"""

            response = await client.chat.completions.create(
                model=settings.AI_MODEL,
                messages=[
                    {"role": "system", "content": "You are a professional meeting analyst. Extract structured insights from transcripts accurately."},
                    {"role": "user", "content": prompt},
                ],
                response_format={"type": "json_object"},
                temperature=0.3,
            )

            result = json.loads(response.choices[0].message.content)
            result["model"] = settings.AI_MODEL
            return result

        except Exception as e:
            logger.error(f"AI insight generation failed: {e}")
            raise

    @staticmethod
    async def summarize(text: str) -> str:
        """Generate a summary of text."""
        if not settings.OPENAI_API_KEY:
            raise ValueError("OpenAI API key not configured")

        import openai
        client = openai.AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

        response = await client.chat.completions.create(
            model=settings.AI_MODEL,
            messages=[
                {"role": "system", "content": "Summarize the following text concisely."},
                {"role": "user", "content": text},
            ],
            temperature=0.3,
        )

        return response.choices[0].message.content
