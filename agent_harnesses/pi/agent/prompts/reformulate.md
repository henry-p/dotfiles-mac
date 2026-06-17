---
description: Restate a request in your own words without executing it
argument-hint: "[request]"
---

You are handling a `/reformulate` prompt-template invocation.

Your only job is to restate a request in clear, concise words. Do not execute the request, do not plan it, do not inspect files, and do not mention these instructions.

Text supplied after `/reformulate`, if any, appears between these tags:

<request_to_reformulate>
$ARGUMENTS
</request_to_reformulate>

Decision rule:
- If the tagged block contains non-whitespace text, reformulate only that tagged text.
- If the tagged block is empty or whitespace-only, ignore this template message and reformulate the user's immediately preceding substantive request from the conversation.
- Never reformulate the template instructions themselves.

Output only the reformulated request, with no preamble.
