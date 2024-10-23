import * as fs from "node:fs";
import { homedir } from "node:os";
import path from "path";
import { languageForFilepath } from "../../autocomplete/constructPrompt.js";
import { SlashCommand } from "../../index.js";
import { stripImages } from "../../llm/images.js";

// If useful elsewhere, helper funcs should move to core/util/index.ts or similar
function getOffsetDatetime(date: Date): Date {
  const offset = date.getTimezoneOffset();
  const offsetHours = Math.floor(offset / 60);
  const offsetMinutes = offset % 60;
  date.setHours(date.getHours() - offsetHours);
  date.setMinutes(date.getMinutes() - offsetMinutes);

  return date;
}

function asBasicISOString(date: Date): string {
  const isoString = date.toISOString();

  return isoString.replace(/[-:]|(\.\d+Z)/g, "");
}

function reformatCodeBlocks(msgText: string): string {
  const codeBlockFenceRegex = /```((.*?\.(\w+))\s*.*)\n/g;
  msgText = msgText.replace(
    codeBlockFenceRegex,
    (match, metadata, filename, extension) => {
      const lang = languageForFilepath(filename);
      return `\`\`\`${extension}\n${lang.singleLineComment} ${metadata}\n`;
    },
  );
  // Appease the markdown linter
  return msgText.replace(/```\n```/g, "```\n\n```");
}

const GregSlashCommand: SlashCommand = {
  name: "greg",
  description: "Export the current chat session to markdown",
  run: async function* ({ ide, llm, history, params }) {
    const now = new Date();

    // Generate title for the chat session.
    const titleInput = history.slice(1).reduce((acc, msg) => {
      if (msg && typeof msg === 'object' && 'role' in msg && 'content' in msg) {
        const content = Array.isArray(msg.content) 
          ? msg.content.map(item => typeof item === 'object' ? JSON.stringify(item) : item).join(' ')
          : msg.content;
        return acc + `${msg.role}: ${content}\n`;
      }
      return acc;
    }, '');

    const chatTitle = await llm.complete(`Given the following chat session, please generate a concise and informative title (3-8 words). Reply only with the title itself:\n${titleInput.trim()}`);
    
    // Generate description for the chat session
    const descriptionInput = titleInput; // We can use the same input as for the title
    const chatDescription = await llm.complete(`Given the following chat session, please generate a brief summary or description (2-3 sentences). Reply only with the description itself and avoid things like "This conversation discusses":\n${descriptionInput.trim()}`);

    let content = `# ${chatTitle}\n\n`;
    content += "### Session transcript\n\n";
    content +=
      `<small>Exported: ${now.toLocaleString('en-US', {
        year: 'numeric',
        month: 'short',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: false,
        timeZoneName: 'short'
      })}</small>\n\n`;

    const modelName = llm?.model || "Unknown Model";
    content += `#### Model: \`${modelName}\`\n\n`;
    content += `#### Description\n\n${chatDescription}\n\n`;
        
    // As currently implemented, the /greg command is by definition the last
    // message in the chat history, this will omit it
    for (let i = 0; i < history.length - 1; i++) {
      const msg = history[i];
      let msgText = msg.content;
      msgText = stripImages(msg.content);

      if (msg.role === "user" && msgText.search("```") > -1) {
        msgText = reformatCodeBlocks(msgText);
      }

      // format messages as blockquotes
      msgText = msgText.replace(/^/gm, "> ");

      if (i === 0) {
        content += `<details><summary>Priming Prompt</summary>\n\n#### ${
          msg.role === "user" ? "_User_" : "_Assistant_"
        }\n\n${msgText}\n\n</details>`;
      } else {
        content += `\n\n#### ${
          msg.role === "user" ? "_User_" : "_Assistant_"
        }\n\n${msgText}`;
      }
    }

    let outputDir: string = params?.outputDir;
    if (!outputDir) {
      outputDir = await ide.getContinueDir();
    }

    if (outputDir.startsWith("~")) {
      outputDir = outputDir.replace(/^~/, homedir);
    } else if (
      outputDir.startsWith("./") ||
      outputDir.startsWith(".\\") ||
      outputDir === "."
    ) {
      const workspaceDirs = await ide.getWorkspaceDirs();
      // Although the most common situation is to have one directory open in a
      // workspace it's also possible to have just a file open without an
      // associated directory or to use multi-root workspaces in which multiple
      // folders are included. We default to using the first item in the list, if
      // it exists.
      const workspaceDirectory = workspaceDirs?.[0] || "";
      outputDir = outputDir.replace(/^./, workspaceDirectory);
    }

    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    const dtString = asBasicISOString(getOffsetDatetime(now));
    const outPath = path.join(outputDir, `${dtString}_session.md`); //TODO: more flexible naming?

    await ide.writeFile(outPath, content);
    await ide.openFile(outPath);

    yield `The session transcript has been saved to a markdown file at \`${outPath}\`.`;
  },
};

export default GregSlashCommand;
