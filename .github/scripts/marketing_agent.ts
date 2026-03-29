import { spawnSync } from "child_process";

async function run() {
  // 1. GATHER ALL CONTEXT (The "Anti-Chambonada" Layer)
  const history = spawnSync("git", ["log", "--oneline", "-n", "30"]).stdout.toString();
  const currentTag = spawnSync("git", ["describe", "--tags", "--abbrev=0"]).stdout.toString().trim() || "v0.1.0-alpha";
  const commitMsg = spawnSync("git", ["log", "-1", "--pretty=%B"]).stdout.toString().trim();
  const diff = spawnSync("git", ["diff", "HEAD~1", "HEAD", "--stat"]).stdout.toString().trim();

  // Load all 3 READMEs for full architectural awareness
  let rootRM = "", contractRM = "", frontendRM = "";
  try { rootRM = await Bun.file("README.md").text(); } catch(e) {}
  try { contractRM = await Bun.file("contracts/README.md").text(); } catch(e) {}
  try { frontendRM = await Bun.file("frontend/README.md").text(); } catch(e) {}

  // 2. FETCH MEMORY FROM GOOGLE SHEETS
  let pastProposals = "First time tweeting. Start the legend.";
  try {
    const memRes = await fetch(process.env.GOOGLE_DEPLOYMENT_URL!);
    const memData = await memRes.json();
    if (memData.length > 0) pastProposals = JSON.stringify(memData);
  } catch (e) { console.log("New memory initialized."); }

  const prompt = `
    ROLE: Lead Marketing Engineer @ VaultChain (2026).
    TONE: Cypherpunk, Minimalist, High-Tech, Elite. Focus on Digital Sovereignty and Consumer Ownership.
    
    KNOWLEDGE BASE:
    - Architecture: ${rootRM.slice(0, 400)}
    - Contracts (Stylus/Rust): ${contractRM.slice(0, 400)}
    - Frontend (Bun/Next.js): ${frontendRM.slice(0, 400)}
    - Current Release: ${currentTag}
    - Recent Evolution: ${history}
    - Marketing Memory: ${pastProposals}

    CURRENT CHANGE:
    - Message: ${commitMsg}
    - Technical Delta: ${diff}

    MARKETING STRATEGY:
    - If this is the FIRST post (Memory is empty), introduce the vision without revealing everything.
    - If this is a "fix", be tactical/security-focused. If "feat", be epic/visionary.
    - Aim for Investors (Scalability/Sovereignty) and Users (Privacy/Ownership).
    
    TASK:
    1. Write TWO (2) different options in ENGLISH.
    2. Write ONE (1) version in SPANISH.
    3. Include a "Thread Idea" if the technical change is complex.
    4. Start with a hook against centralized cloud. End with technical authority (Rust/Irys).
    5. Max 280 chars per post. No corporate fluff. No emojis.
  `;

  try {
    const groqRes = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${process.env.GROQ_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "llama-3.1-70b-versatile",
        messages: [{ role: "system", content: prompt }],
        temperature: 0.7
      })
    });

    const data = await groqRes.json();
    const proposal = data.choices[0].message.content;

    // 3. PERSIST & NOTIFY
    await fetch(process.env.GOOGLE_DEPLOYMENT_URL!, {
      method: "POST",
      body: JSON.stringify({ action: "saveProposal", tag: currentTag, commit: commitMsg, proposal })
    });

    await fetch(process.env.DISCORD_WEBHOOK!, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        content: `## 🛸 VaultChain Intelligence [${currentTag}]\n\n${proposal}\n\n---\n**Management:**\n[Open Memory Sheet](${process.env.SHEET_URL})`
      })
    });

    console.log("Marketing intelligence dispatched.");
  } catch (err) {
    console.error("Agent failed:", err);
    process.exit(1);
  }
}

run();
