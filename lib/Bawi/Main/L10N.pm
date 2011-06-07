package Bawi::Main::L10N;

use strict;

use base qw(Locale::Maketext);
use vars qw( %Lexicon );

%Lexicon = (
    _AUTO => 1,
    'T_BOOKMARK' => 'Bookmarks',
    'T_BOARD' => 'Board',
    'T_BOARDS' => 'Boards',
    'T_ONLINE' => 'Online Users',
    'T_USERLIST' => 'User List',
    'T_ADDUSER' => 'Add Users',
    'T_PASSWD' => 'Change Password',
    'T_SIG' => 'Edit Signature',
    'T_LOGOUT' => 'Logout',
    'T_PREV' => 'PREV',
    'T_NEXT' => 'NEXT',
    'T_WRITE' => 'Write',
    'T_EDIT' => 'Edit',
    'T_DELETE' => 'Delete',
    'T_REPLY' => 'Reply',
    'T_THREAD' => 'Thread',
    'T_READ' => 'Read',
    'T_RECOMMEND' => 'Recommend',
    'T_RECOMMENDED' => 'Recommended',
    'T_SCRAP' => 'Scrap',
    'T_SCRAPPED' => 'Scrapped',
    'T_SCRAPBOOK' => 'Scrapbook',
    'T_RESET' => 'Reset',
    'T_NEWARTICLES' => 'New Articles',
    'T_TITLE' => 'Title',
    'T_BODY' => 'Body',
    'T_NAME' => 'NAME',
    'T_ID' => 'ID',
    'T_FILE' => 'File',
    'T_POLL' => 'Poll',
    'T_OPTION' => 'Option',
    'T_SAVE' => 'Save',
    'T_IMGLIST' => 'ImageList',
    'T_ARTICLELIST' => 'ArticleList',
    'T_SEARCH' => 'Search',
    'T_COMMENT' => 'Comment',
    'T_NEWCOMMENTS' => 'New comments',
    'T_ADDBOOKMARK' => 'AddToBookmark',
    'T_DELBOOKMARK' => 'DeleteFromBookmark',
    'T_BOARDCFG' => 'BoardConfiguration',
    'T_ADDNOTICE' => 'AddToNoticeList',
    'T_DELETENOTICE' => 'DeleteFromNoticeList',
    'T_COMMENT' => 'Comment',

);

sub language_name {
    my $tag = $_[0]->language_tag;
    require I18N::LangTags::List;
    I18N::LangTags::List::name($tag);
}

sub encoding { 'iso-8859-1' }   ## Latin-1

1;
