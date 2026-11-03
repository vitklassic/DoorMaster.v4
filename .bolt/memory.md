# Project memory

## Product intent & audience

- Mobile app for measuring door openings (замер дверей) built with Expo/React Native
- Primary users: door measurers (замерщики) who record dimensions on-site
- Secondary users (unconfirmed): managers and/or clients who may view measurement results
- Core workflow: home screen → create new or open existing → fill form → save → review/share report
- Russian-language UI

## Brand personality & voice

- Practical, professional tool for field work
- Clear, concise copy; step-by-step guidance
- Helper visuals/instructions for each dimension

## Visual design & UX direction

- **Home screen**: two primary choices — «Создать новый замер» and «Просмотреть готовый замер»
- Bottom tab navigation: «Новый замер», «Мои замеры», «Настройки»
- **New measurement form**: step 1 fields — адрес (required), ФИО (required), номер подъезда, этаж (numeric only)
- One measurement (замер) can contain multiple door openings (проёмы); each opening is measured separately
- **Room selection**: fixed list — зал, кухня, ванная, с/у, спальня, детская, кладовая, постирочная, гардероб, тамбур, подвал; plus «Другое» for custom room name
- **Auto-numbering**: duplicate rooms in same замер get sequential index (спальня 1, спальня 2…); numbering resets per замер; visible in opening list and report
- **Door opening direction**: на себя влево / на себя вправо / от себя влево / от себя вправо / раздвижные по наружной стене / раздвижные по внутренней стене
- **Opening schema (схема проёма)**: visual diagram shown next to dimension fields; changes based on selected opening direction; included in final report
  - **No dimension labels/numbers on schema** — only shape, opening direction, and «коридор» caption
  - All dimensions stay in input fields and final report, not on the diagram
- **Units**: all dimensions (height, width, thickness) entered and stored in millimeters; «мм» shown in input fields to prevent cm/mm confusion
- Two separate floor selection fields (details pending — see open questions)
- **Opening input order**: этаж per opening → помещение from list → фото (optional) → высота → ширина → толщина (each confirmed individually, all in мм) → сторона открывания → schema appears
- After thickness, app offers to measure next opening
- Inline validation: required fields, sanity-check values (too small/large numbers get warnings)
- Measurement list with search by address and ФИО; date shown; edit/delete entries
- Photo attachment support for each measurement
- Report generation: shareable via email, messenger, or file export
- Settings: measurement units, company name, logo
- Large, one-handed-friendly buttons on mobile
- Potential login/multi-user accounts (unconfirmed)
- Offline capability likely needed (field work, poor connectivity) — unconfirmed

## Decisions, constraints & rationale

- Expo chosen as framework (mobile-first, cross-platform)
- Persistent local storage required so measurements survive app close
- Home screen simplifies to two main actions before deeper navigation
- First form step collects object info (address, ФИО, подъезд, этаж) before door dimensions
- One замер = one object with multiple проёмы; room + opening direction per проём
- Fixed room list with custom option reduces input time on-site
- Auto-numbering identical rooms avoids confusion when multiple doors of same room type
- Opening direction options replaced earlier «прямая/реверсивная» concept (status pending — see open questions)
- Opening schema visual helps measurer verify correct dimensions against real opening
- **Schema kept clean**: no dimension numbers on diagram to avoid clutter on small screens; «коридор» caption only
- **Millimeters as sole unit**: eliminates cm/mm confusion on-site; «мм» label always visible in input fields
- **Schema diagrams**: swing door — opening with door ajar (thinner line), «коридор» at bottom; sliding door — door along wall per selected variant, «коридор» label
- Phased plan: measurement form + storage first → reports + team access later
- Door types may need field-set variations (unconfirmed)

## Open questions & assumptions

- ФИО: client or measurer?
- Apartment number (квартира) needed alongside address?
- Second этаж field meaning: object floor vs. door-level floor vs. something else?
- Save object card before measuring openings, or proceed directly?
- Who uses the app: measurers only, or also managers/clients?
- Offline-first requirement confirmed?
- Distinct door types with custom field sets per type?
- Existing company measurement-sheet template to match?
- User accounts/login or single-user sufficient?
- Brand colors, fonts, app name not yet defined
- Report format: PDF, image, or structured shareable text?
- «Прямая или реверсивная» — keep alongside opening-direction options or remove?
- Opening schema for sliding doors: what values to show, and should wall/corridor be depicted?
