# Embedding Agent 0 Inside the Power BI Dashboard

Goal: one Power BI report page showing your charts alongside a live chat window for Agent 0, so a user never has to leave the dashboard to ask a question or make an entry.

Architecture: **Power BI report → Power Apps visual → Canvas App → Copilot Studio "Chat" control → Agent 0**

---

## Part 1 — Build the Canvas App

### 1. Create the app
1. Go to **make.powerapps.com**, sign in with your work account.
2. Click **Create** (left sidebar) → choose **Blank app** → **Canvas** app type.
3. Pick **Tablet** layout (wider, fits a Power BI tile better than Phone).
4. Name it **"HRD Agent Chat"** → **Create**. This opens Power Apps Studio.

### 2. Add the chat control
1. Click **Insert** (left sidebar, "+" icon).
2. Find the **AI** (or **Copilot**) category in the controls list.
3. Drag a **Chat** (or **"Copilot"**) control onto the blank screen.
4. With it selected, find its property panel (right side) → look for **Bot** / **Copilot agent** → select **Agent 0 — Orchestrator** from the dropdown.
5. Drag the control's corner handles so it fills most/all of the screen.

### 3. Save and publish
1. **File** (top left) → **Save** → add a version note if asked → **Save**.
2. Click **Publish**.

### 4. Test it standalone first
Open the app on its own (Power Apps → **Apps** → click "HRD Agent Chat" → **Play**) and send it a test question. Confirm it behaves exactly like chatting with Agent 0 directly in Copilot Studio — same answers, same write-back/forecast behavior. If it works here, it'll work embedded too; if it doesn't, fix it here before touching Power BI at all.

---

## Part 2 — Embed it in Power BI

### 5. Add the Power Apps visual
1. Open your **CCM_Dashboard** report in Power BI Desktop.
2. Decide which page/area gets the chat — could be a corner of your existing Overview page, or its own dedicated page (e.g., a new tab called "Ask the Assistant"). A dedicated page is simpler to start with — avoids fighting for space with existing charts.
3. In the **Visualizations** pane, find and click the **Power Apps** visual icon (may be under "More visuals" if not pinned — search "Power Apps" if you don't see it immediately).
4. Drag it onto the canvas and resize it to take up the space you want (e.g., most of a blank page).

### 6. Connect it to your Canvas App
1. With the Power Apps visual selected, a panel appears (usually says "Create new" or "Choose an existing app").
2. Choose **"Work with an existing app"** (or similar wording) and pick **"HRD Agent Chat"** from the list.
3. It may ask you to add at least one data field into the visual's **Data** well (some versions of this visual require a field to exist even if the app doesn't use it directly, just to keep the visual active) — if prompted, add any simple field like `cost_center_name` as a placeholder.
4. The canvas app should now render live inside the Power BI canvas — you should see your chat control appear right there in the report.

### 7. Test inside Power BI Desktop
Type a test question directly into the embedded chat, right there in the Power BI report. Confirm it responds correctly, same as the standalone test in step 4.

---

## Part 3 — Publish and share

### 8. Publish the report
Same as before — **Publish** button (Home ribbon) → pick your workspace.

### 9. Share the Canvas App with your viewers — important, easy to miss
Publishing the Power BI report does **not** automatically give people permission to use the embedded app. You need to separately share the Canvas App itself:
1. Go back to **make.powerapps.com** → **Apps** → find "HRD Agent Chat".
2. Click **"..."** (more options) → **Share**.
3. Add the same people/group who have access to the Power BI report.
4. Give them **"Can use"** permission (they don't need "Can edit").
5. Click **Share**.

Without this step, other viewers will see a blank or error tile where the chat should be, even though it works fine for you.

### 10. Final test as a different user (if possible)
If you can, have someone else open the published Power BI report and confirm the embedded chat actually works for them too — this is the real proof it's genuinely usable by your audience, not just by you as the app's owner.

---

## Things to watch for

- **Licensing**: if step 5 or 6 throws a licensing error, this Power Apps visual/Canvas App combo may need a Power Apps license tier your account or your viewers' accounts don't currently have. Check with your Power Platform admin if this happens — not something you can fix from inside the app itself.
- **Performance**: an embedded chat inside a Power BI report can feel slightly more sluggish than the standalone Copilot Studio chat window, since it's rendering inside an iframe-like visual. Not a bug, just a natural tradeoff of this approach.
- **Editing later**: any future changes to Agent 0 (new tools, updated instructions) apply automatically here too — the Canvas App just points at the live agent, it doesn't create a separate copy of it.
