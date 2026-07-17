# Spa & Salon Management Platform - Project Description

## 1. Overview
The **Spa & Salon Management Platform** is a modern, full-stack application designed to manage bookings, employees, and customers for spa and salon businesses. It implements the "Hallmark V3" design language, ensuring a premium, highly interactive, and intuitive user experience (UX) for both receptionists (desktop) and therapists (mobile).

## 2. Technology Stack
*   **Frontend**: Next.js (App Router), React, Tailwind CSS, Shadcn UI.
*   **Backend & Database**: Supabase (PostgreSQL).
*   **API & Mutations**: Next.js Server Actions (for data mutations) and React Query / Supabase Realtime (for data fetching and live updates).
*   **Design System**: Custom "Hallmark V3" (Anti-AI-slop design) with specific themes like Coral/Amber, Zebra-striping in time-grids, and Inset Cards for mobile.

## 3. Architecture Principles
*   **Pure SQL for the API**: Business logic is centralized in the PostgreSQL database using RPCs (Stored Procedures), Views, and Row Level Security (RLS). This reduces the need for a custom Node.js backend.
*   **Strict Client/Server Separation**: Server Actions and queries are handled securely on the server via `@supabase/ssr`, while highly interactive components (like the Calendar) use Supabase WebSockets (`supabase.channel`) for real-time updates.
*   **Optimistic UI & Idempotency**: Critical operations like booking and checkout support optimistic UI updates to prevent UI blocking, and include idempotency keys to prevent double-charging or double-booking.
*   **Robust Error Sanitization**: Raw PostgreSQL errors are never exposed to the client. A dedicated `errorHandler.ts` translates database exceptions (e.g., exclusion constraints) into actionable user messages.

## 4. Current State (Theoretical vs. Practical)
### Theoretical Correctness:
The architecture is mathematically and logically sound. The database schema includes all necessary constraints (e.g., overlapping appointment prevention using `EXCLUDE`). The API layer accurately implements the bridge using Next.js Server Actions.

### Practical & Testing State:
*   **TypeScript Checks**: Passed (`npx tsc --noEmit` completed without errors).
*   **Database Synchronisation**: Migration scripts (`initial_schema`, `api_logic`) are generated locally but require `npx supabase link` and `npx supabase db push` to be applied to the live Supabase project.
*   **End-to-End Testing**: Cannot be fully run until the Supabase database is synced and environment variables (`NEXT_PUBLIC_SUPABASE_URL`, etc.) are configured locally.

## 5. Core Features
*   **Role-based Dashboards**: Specific views for Receptionists (managing all bookings) and Therapists (viewing their own schedules).
*   **Booking Management**: Create, update, and checkout appointments.
*   **Real-time Calendar**: Drag-and-drop or click-to-book interfaces that update instantly across all active sessions.
*   **Employee & Service Management**: CRUD operations for spa services and staff members.
*   **Customer Segmentation**: Automated daily customer segmentation using `pg_cron`.
