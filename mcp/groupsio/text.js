// Turn a groups.io message body into just the new text the sender wrote:
// HTML -> plain text, then drop quoted reply chains, signatures, and list footers.

const ENTITIES = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " " };

export function htmlToText(html) {
  return html
    // Quoted history in Gmail/Apple/Outlook replies.
    .replace(/<blockquote[\s\S]*?<\/blockquote>/gi, "")
    .replace(/<div[^>]*class="[^"]*(gmail_quote|gmail_extra|yahoo_quoted|moz-cite-prefix)[^"]*"[\s\S]*$/i, "")
    .replace(/<(style|script)[\s\S]*?<\/\1>/gi, "")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|div|li|tr|h\d)>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&(#\d+|#x[0-9a-f]+|\w+);/gi, (m, e) => {
      if (e[0] === "#") {
        const code = e[1].toLowerCase() === "x" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
        return Number.isFinite(code) ? String.fromCodePoint(code) : m;
      }
      return ENTITIES[e.toLowerCase()] ?? m;
    });
}

// Lines where the quoted history (or other noise) starts; everything from here down is dropped.
const CUT_MARKERS = [
  /^\s*On .+wrote:\s*$/i, // Gmail / Apple Mail attribution line
  /^\s*-+\s*Original Message\s*-+/i,
  /^\s*From:\s.+/i, // Outlook-style header block
  /^\s*_\._,_\._,_/, // groups.io footer delimiter
  /^\s*Groups\.io Links:/i,
  /^\s*Sent from my (iPhone|iPad|Android|phone)/i,
  /^\s*--\s*$/, // signature delimiter
];

export function stripReply(body, { isPlainText = true } = {}) {
  let text = isPlainText ? body : htmlToText(body);
  text = text.replace(/\r\n?/g, "\n");

  // Gmail often wraps the attribution across two lines:
  //   "On Wed, Nov 11, 2026 at 8:51 PM Tyler via crozetbikepolo <tyler=\ngmail.com@groups.io> wrote:"
  text = text.replace(/^(\s*On [^\n]+)\n([^\n]*wrote:\s*)$/gim, "$1 $2");

  const out = [];
  for (const line of text.split("\n")) {
    if (CUT_MARKERS.some((re) => re.test(line))) break;
    if (/^\s*>/.test(line)) continue; // inline-quoted lines
    out.push(line);
  }

  return out
    .join("\n")
    .replace(/[ \t ]+$/gm, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}
