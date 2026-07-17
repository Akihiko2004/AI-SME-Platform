# User Behavior & Direction Log

## 1. Overview
This document meticulously chronicles the user's behavior, decision-making patterns, and strategic directions throughout the development of the "Spa & Salon Management Platform".

## 2. Core Behavior Patterns

### 2.1. High Standards for UI/UX (The "Anti-AI-Slop" Philosophy)
*   **Behavior**: The user consistently demanded a premium, non-generic user interface. They explicitly rejected "AI-slop" designs (standard, uninspired layouts).
*   **Action Taken**: The user mandated the adoption of a specific design repository (`Nutlope/hallmark`) and forced the AI agent to rigorously analyze its source code to extract the "Hallmark V3" design language.
*   **Outcome**: The platform uses specific aesthetic rules: Coral/Warm Neutral themes, Zebra-striping for data grids, and Click-to-toggle drawers instead of hover-based sidebars.

### 2.2. Focus on Robust, Scalable Architecture
*   **Behavior**: The user shifted the initial technology stack from a custom Python/FastAPI backend to a pure Supabase (PostgreSQL) backend.
*   **Action Taken**: The user directed the creation of an extensive engineering specification (`Backend Specification`). They insisted on putting business logic (like booking conflict resolution) directly into PostgreSQL via RPCs and Triggers, rather than writing it in the application layer.
*   **Outcome**: A highly secure, single-source-of-truth architecture that relies heavily on Row Level Security (RLS) and database constraints.

### 2.3. Rigorous Quality Assurance & Multi-Agent Orchestration
*   **Behavior**: The user does not blindly trust single-agent outputs. They frequently employ advanced prompt engineering techniques and slash commands (e.g., `/multi-agent-task-orchestrator`, `/multi-agent-brainstorming`, `/goal`, `/deep-research`).
*   **Action Taken**: 
    *   The user forced the AI to double-check its own work ("double lại đã đầy đủ chức năng ứng với mô tả chưa").
    *   They mandated the use of a "Multi-Agent Brainstorming" process where simulated agents (Skeptic, Constraint Guardian, User Advocate) critiqued the API design before implementation.
*   **Outcome**: The API architecture was significantly improved. Potential issues like cache desynchronization, double-booking, and database overload (from polling) were caught and resolved (switching to WebSockets/Realtime and implementing idempotency keys) *before* any code was written.

### 2.4. Methodical Progress and Reporting
*   **Behavior**: The user requires explicit, structured reports of progress.
*   **Action Taken**: They issued commands like "báo cáo lại từng chức năng một" (report each function one by one) and "tổng hợp lại toàn bộ... để nghiệm thu" (summarize everything for acceptance testing).
*   **Outcome**: The project maintains a highly documented state, utilizing multiple artifact files (`decision_log.md`, `ux_ui_design_hallmark.md`, etc.) to track every architectural and design decision.

## 3. Summary of User's Persona
The user acts as a rigorous **Technical Product Manager / Software Architect**. They are deeply concerned with both the extreme end of user experience (micro-interactions, color theory) and the absolute lowest level of data integrity (database constraints, API latency). They utilize AI not just as a code generator, but as a team of engineers that must be orchestrated, challenged, and verified.
