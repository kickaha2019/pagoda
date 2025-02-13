create table alias (
  id int not null,
  name text not null unique,
  hide int,
  foreign key (id) references game(id)
) strict;

create index alias_id on alias (id);

create index alias_name on alias (name);

create table aspect (
  name text primary key,
  'index' int not null unique,
  type text,
  derive int
) strict;

create table bind (
  url text primary key,
  id int not null,
  foreign key (url) references link(url)
) strict;

create index bind_id on bind (id);

create table company_alias (
  name text not null,
  'alias' text not null unique,
  foreign key (name) references company(name)
) strict;

create index company_alias_name on company_alias (name);

create table company (
  name text not null primary key
) strict;

create table game_aspect (
  id int not null,
  aspect text not null,
  flag int,
  foreign key (id) references game(id),
  foreign key (aspect) references aspect(name)
) strict;

create index game_aspect_id on game_aspect (id);

create table game (
  id int primary key,
  name text not null unique,
  is_group int,
  group_id int,
  game_type text,
  year int,
  developer text,
  publisher text
) strict;

create index game_name on game (name);

create table history (
  timestamp int primary key,
  site text not null,
  type text not null,
  method text not null,
  state text,
  elapsed real not null,
  found int
) strict;

create table link (
  url text primary key,
  site text not null,
  type text not null,
  title text not null,
  digest text,
  timestamp int not null,
  valid int not null,
  comment text,
  reject int not null,
  year int,
  static int not null,
  orig_title text
) strict;

create table suggest (
  url text primary key,
  site text not null,
  type text not null,
  title text not null
) strict;

create table tag_aspects (
  tag text not null,
  aspect text not null,
  foreign key (aspect) references aspect(name)
) strict;

create index tag_aspects_tag on tag_aspects (tag);

create table visited (
  key text primary key,
  timestamp int not null
) strict;
