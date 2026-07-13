-- Migration to add osi_name column to buildings table
alter table if exists public.buildings
  add column if not exists osi_name text;
