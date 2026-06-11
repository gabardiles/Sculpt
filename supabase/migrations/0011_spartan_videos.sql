-- 0011_spartan_videos.sql
--
-- Curated YouTube instruction videos for the 13 global exercises added for the
-- "Spartan" program. URLs use the privacy-enhanced youtube-nocookie.com/embed/
-- form so the app can embed them in an iframe.
--
-- Each video ID was found via web search against the live YouTube index
-- (June 2026) and chosen from form-focused channels (Jeff Nippard,
-- Squat University, Renaissance Periodization, Buff Dudes).
--
-- Idempotent: plain UPDATEs keyed on the unique global exercise name.

update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/vcBig73ojpE' where name = 'Barbell Bench Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/d2uus7QUt4c' where name = 'Overhead Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/yN6Q1UI_xkE' where name = 'Weighted Dip' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/s5hluoQjtIM' where name = 'Weighted Pull-Up' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/7B5Exks1KJE' where name = 'Barbell Row' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/cXbSJHtjrQQ' where name = 'Close-Grip Bench Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/cc0tasCalHg' where name = 'Face Pull' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/4Xr7bKE_fxE' where name = 'Dumbbell Rear Delt Fly' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/5YK4bgzXDp0' where name = 'Reverse Pec Deck' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/dI3jB_cfLwg' where name = 'Band Pull-Apart' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/fKMIHZD9S98' where name = 'Dumbbell Front Raise' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/4mfLHnFL0Uw' where name = 'Cable Fly' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/FDay9wFe5uE' where name = 'Machine Chest Fly' and is_global;
