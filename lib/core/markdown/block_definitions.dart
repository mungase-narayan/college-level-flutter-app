/// Port of `src/lib/content/blocks.ts`.
///
/// Every rich block the composer can insert is a fenced code block whose
/// language tag names the block and whose body is JSON. That keeps the source
/// valid markdown — an unsupported block degrades to a readable code block
/// rather than disappearing — and gives one parser for all of them.
///
/// This file is the single source of truth for which fences are blocks; the
/// parser and the renderer both read [kBlockKeys], so a key can never be
/// handled in one place and missed in the other.
library;

/// Where a block sits in the web app's Add-block menu. Carried across so the
/// two codebases describe the same set the same way, even though the mobile
/// app has no authoring UI yet.
enum BlockGroup { learning, media, layout, callouts }

/// The 19 fence languages that render as rich blocks, in the order
/// `blocks.ts` declares them.
const List<String> kBlockKeys = [
  'quiz',
  'timeline',
  'video',
  'notice',
  'assignment',
  'playground',
  'flashcards',
  'tabs',
  'cards',
  'stats',
  'faq',
  'alert',
  'button',
  'gallery',
  'pdf',
  'youtube',
  'leetcode',
  'mermaid',
  'accordion',
];

/// Which group each key belongs to, mirroring the `group` field in `blocks.ts`.
const Map<String, BlockGroup> kBlockGroups = {
  'quiz': BlockGroup.learning,
  'assignment': BlockGroup.learning,
  'playground': BlockGroup.learning,
  'flashcards': BlockGroup.learning,
  'leetcode': BlockGroup.learning,
  'video': BlockGroup.media,
  'gallery': BlockGroup.media,
  'pdf': BlockGroup.media,
  'youtube': BlockGroup.media,
  'mermaid': BlockGroup.media,
  'timeline': BlockGroup.layout,
  'tabs': BlockGroup.layout,
  'cards': BlockGroup.layout,
  'stats': BlockGroup.layout,
  'faq': BlockGroup.layout,
  'accordion': BlockGroup.layout,
  'notice': BlockGroup.callouts,
  'alert': BlockGroup.callouts,
  'button': BlockGroup.callouts,
};

/// Fences whose body is *not* JSON. `mermaid` carries diagram syntax, so the
/// renderer must skip the parse step for it exactly as `renderBlock` does.
const Set<String> kRawBodyBlockKeys = {'mermaid'};

bool isBlockKey(String language) => kBlockKeys.contains(language);
