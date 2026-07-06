insert into bw_xauth_passwd (id, name, passwd, email, modified) select id, name,
passwd, email, now() as 'modified' from bw_xauth_new_passwd where
status='recommended' && ki<34 order by ki, name, id;

insert into bw_user_basic (uid, birth, affiliation)
select a.uid, b.birth, b.affiliation from
bw_xauth_passwd as a, bw_xauth_new_passwd as b where a.id=b.id &&
b.status='recommended' && ki<34 order by uid;

insert into bw_user_ki (uid, ki) select a.uid, b.ki from bw_xauth_passwd as a,
bw_xauth_new_passwd as b where  a.id=b.id && b.status = 'recommended' && b.ki<34;

select email from bw_xauth_new_passwd where status='recommended' && ki<34;

update bw_xauth_new_passwd set status='done' where status='recommended' && ki<34;
