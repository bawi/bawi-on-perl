update bw_xboard_comment set body = '[[ 작성자가 삭제하였습니다. ]]' where body like '** Deleted by the author **' limit 800;
update bw_xboard_comment set body = '[[ 작성자가 삭제하였습니다. ]]' where body like '*** Deleted by author ***' limit 800;
