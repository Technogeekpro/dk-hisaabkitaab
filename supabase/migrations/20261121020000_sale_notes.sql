-- Optional note on each sale. Existing sales get an empty note.
alter table public.dk_sales
  add column note text not null default '' check (length(note) <= 200);
