insert into bw_user_basic (uid, birth, affiliation)
select a.uid, b.birth, b.affiliation from
bw_xauth_passwd as a, bw_xauth_new_passwd as b where a.id=b.id &&
b.status='recommended' order by uid;

insert into bw_user_ki (uid, ki) select a.uid, b.ki from bw_xauth_passwd as a,
bw_xauth_new_passwd as b where  a.id=b.id && b.status = 'recommended';

select email from bw_xauth_new_passwd where status='recommended';

update bw_xauth_new_passwd set status='done' where status='recommended';
