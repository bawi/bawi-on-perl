delete from bw_xboard_stat_board;

insert into bw_xboard_stat_board (board_id, counts, articles, comments, recoms)
  select a.board_id, sum(count) as counts, count(b.article_id) as articles, sum(comments) as comments, sum(recom) as recoms
    from bw_xboard_board as a, bw_xboard_header as b
      where a.board_id=b.board_id && a.board_id !=637 && a.board_id != 688 && b.created> date_sub(now(), interval 7 day)
        group by a.board_id order by count desc;

        delete from bw_xboard_stat_user;

        insert into bw_xboard_stat_user (id, name, articles, counts, comments, recoms)
          select id, name, count(article_id) as articles, sum(count) as counts, sum(comments) as comments, sum(recom) as recoms
            from bw_xboard_header where board_id not in (10, 1550) && created >  date_sub(now(), interval 7 day)
              group by id order by counts desc;
