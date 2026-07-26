-- Opt-in voter-added poll options: a poll with allow_user_opt=1 lets a
-- voter type one option of their own at vote time ("기타 (직접 입력)" in
-- _pollset.tmpl, handled by board/poll.cgi).  DEFAULT 0 keeps every
-- existing poll exactly as it is, so this is safe to blind-apply; the
-- table is small, the rebuild is instant.  Apply BEFORE deploying the
-- code: get_pollset selects allow_user_opt unconditionally.
alter table bw_xboard_poll add column allow_user_opt tinyint(1) not null default 0;
