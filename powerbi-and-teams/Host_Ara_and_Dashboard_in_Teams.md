# Hosting Ara + the Dashboard Together in Microsoft Teams

Since the Power BI embed route isn't available in your tenant (no native Power Apps Chat control, and Copilot Studio's Custom website channel is blocked by your Microsoft authentication setting), Teams is the realistic option — and it's confirmed available on your Channels page already.

Result: one Team, with a Dashboard tab and Ara both a click away — not literally the same page, but one shared "home" for the whole system.

---

## Part 1 — Publish Ara to Teams

1. In Copilot Studio, open **Ara** → **Channels** tab (where you already were).
2. Click the **"Microsoft 365 and Microsoft Teams"** card under Microsoft channels.
3. Follow the prompts — there's usually a toggle or button like **"Turn on Teams channel"** or **"Add channel"**. Confirm it.
4. Copilot Studio will generate a way to bring Ara into Teams — this may show as a **direct "Open in Teams" / "Add to Teams" link**, or it may generate an app package you upload manually. Use whichever option is presented.
5. If your organization restricts custom Teams apps (common in corporate tenants), you may see a message about needing admin approval to make it available org-wide. For now, look for an option to add it just **for yourself** or **for a specific team** — this usually doesn't need admin approval and is enough to get started and test.

## Part 2 — Add Ara to a Team

1. Open **Microsoft Teams**.
2. Go to the **Team** (or create one, e.g. "HRD Cost Breakdown") where you want this to live.
3. Click **"..."** next to the Team name, or the **"+"** at the top of a channel, to add an app/tab.
4. Search for **"Ara"** (or whatever it shows as) in the app search.
5. Add it — depending on how it's configured, it may show up as something people can **@mention in the channel**, or as a **personal chat app** they open individually. Test both if unsure which applies.

## Part 3 — Add the Power BI report as a Tab in the same Team

1. In that same Team/channel, click the **"+"** at the top to add a new tab.
2. Search for and select **"Power BI"**.
3. Sign in if prompted.
4. Choose your workspace, then select the **CCM_Dashboard** report.
5. Give the tab a clear name (e.g. "Cost Dashboard") → **Save**.

## Part 4 — Test the whole thing together

1. Open the Team fresh, as if you were a regular user.
2. Confirm you see: a **Dashboard tab** (opens the live Power BI report), and a way to **talk to Ara** (either @mention in the channel, or a separate chat tab/app icon).
3. Ask Ara a real question through Teams and confirm it answers correctly, same as testing directly in Copilot Studio.
4. If you can, have someone else open the same Team and confirm it works for them too — that's the real proof this is usable by your actual audience, not just you.

---

## Things to know

- **Org-wide distribution vs. personal/team-only**: getting Ara approved for anyone in Aramco to install from an app catalog usually requires Teams admin approval (a formal review process). Adding it just to one specific Team for now sidesteps that and is enough for testing and even normal day-to-day use within that Team.
- **This is two tabs, not one screen**: unlike the Power BI embed idea, this doesn't put the chat and charts in the exact same visual space — but it does mean everything lives in one Team, one app window, one click away from each other, which satisfies the "one place" goal practically.
- **Future revisit**: the native Power Apps Chat control and Copilot Studio's website channels are both evolving Microsoft features — worth checking again in a few months in case your tenant's rollout/licensing changes and the original embed idea becomes available later.
