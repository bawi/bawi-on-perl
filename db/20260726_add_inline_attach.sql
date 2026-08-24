-- Per-board flag: suppress the automatic image gallery. read.tmpl includes
-- _attach.tmpl above the article body, which renders every image attachment
-- full-size -- authors who place images in-text (<img
-- src="attach.cgi?atid=N;name=/file.jpg"> on legacy boards, or
-- ![](attach.cgi?...) on markdown boards) get each image duplicated at the
-- top. With inline_attach=1 the attachment list still shows its
-- filename/size/download/detach links, but the big <img> preview block is
-- not rendered. DEFAULT 0 keeps today's behavior for every existing board.
--
-- Safe to blind-apply: bw_xboard_board is tiny (one row per board), the
-- ALTER is instant, and no application code reads or writes the column
-- until the code that knows the flag deploys. Apply BEFORE that deploy --
-- Bawi::Board::save_instance lists the column in its UPDATE, so the code
-- without this column applied would fail every board-config save.

ALTER TABLE bw_xboard_board ADD COLUMN inline_attach tinyint(1) NOT NULL DEFAULT 0 AFTER allow_attach;
