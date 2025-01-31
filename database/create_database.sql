create table alias (
  id int not null,
  name text not null unique,
  hide int,
  foreign key (id) references game(id)
) strict;

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

create table company_alias (
  name text not null,
  'alias' text not null unique,
  foreign key (name) references company(name)
) strict;

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

create table history (
  timestamp int primary key,
  site text not null,
  type text not null,
  method text not null,
  state text,
  elapsed real not null
) strict;

create table link (
  url text primary key,
  site text not null,
  type text not null,
  title text not null,
  timestamp int,
  valid int,
  comment text,
  reject int,
  year int,
  static int
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

create table visited (
  key text primary key,
  timestamp int not null
) strict;
