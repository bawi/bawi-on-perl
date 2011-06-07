delete from bw_xboard_stat_article;
insert into bw_xboard_stat_article (board_id, article_id, title, id, name, count, recom, comments, created, ki)
  select a.board_id, a.article_id, a.title, a.id, a.name, a.count, a.recom, a.comments, a.created, count(distinct b.ki) as ki
    from bw_xboard_header as a, bw_user_ki as b, bw_xboard_recom as c
      where b.uid=c.uid && a.article_id=c.article_id && a.created >  date_sub(now(), interval 30 day)
              && a.recom > 2 && a.count > 20 && a.count < 4000 && a.article_id != 1364142
                group by a.article_id order by a.recom desc, a.count desc, a.comments desc;
