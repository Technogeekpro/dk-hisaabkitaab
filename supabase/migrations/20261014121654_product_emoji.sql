alter table public.dk_products
  add column emoji text not null default '📱'
  check (char_length(emoji) between 1 and 32);

alter table public.dk_sales
  add column product_emoji text not null default '📱'
  check (char_length(product_emoji) between 1 and 32);
