-- 0003_instruction_videos.sql
--
-- Curated YouTube instruction videos for the 30 global exercises used by the
-- "Lean & Sculpted" program. URLs use the privacy-enhanced
-- youtube-nocookie.com/embed/ form so the app can embed them in an iframe.
--
-- Each video ID was found via web search against the live YouTube index
-- (June 2026) and chosen from form-focused channels (Squat University,
-- Renaissance Periodization, Buff Dudes, Bret Contreras, Physique
-- Development, NASM, MedBridge, Team Evolve, etc.).
--
-- Idempotent: plain UPDATEs keyed on the unique global exercise name.

update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/KecWzqYscYc' where name = 'Romanian Deadlift' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/qFxTNOiQIAU' where name = 'Hip Thrust' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/DeCnHqrN22U' where name = 'Bulgarian Split Squat' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/3nDCUmratPs' where name = 'Cable Donkey Kicks' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/I4ApZY585nE' where name = 'Seated Hip Abduction Machine' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/yXopOhzEoeo' where name = 'Cable Pull-Through' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/O94yEoGXtBY' where name = 'Lat Pulldown' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/XaHV_8Nbyug' where name = 'Seated Cable Row' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/1jYq9QQEWqE' where name = 'Dumbbell Shoulder Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/n5dsI9qQXwY' where name = 'Lateral Raises' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/qHDrQglWgS4' where name = 'Triceps Rope Pushdown' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/M2Nbw9tunoY' where name = 'Bicep Curls' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/SbgHegC6lEs' where name = 'Back Squat' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/Pbmj6xPo-Hw' where name = 'Walking Lunges' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/cDGOn-yfKJA' where name = 'Leg Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/6ombApkDsf4' where name = 'Hip Thrust Machine' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/bGlm-qTnfTI' where name = 'Standing Cable Hip Abduction' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/Xa18jxyeSnM' where name = 'Calf Raises' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/mUoo2l-p8Hw' where name = 'Close-Grip Lat Pulldown' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/nMFCMNKnLgQ' where name = 'Single-Arm Dumbbell Row' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/GFqfIInCuUQ' where name = 'Back Extension' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/aBd6T01PBqw' where name = 'Cable Crunch' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/_2xWmYNnFS8' where name = 'Pallof Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/xst2FFsIa74' where name = 'Plank with Reach' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/pcY33kEoKZ4' where name = 'Sumo Squat' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/jbJBXErKD-U' where name = 'Frog Pumps' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/tqECKZxlCKE' where name = 'Step-Ups' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/bVrmtCI00Ys' where name = 'Cable Kickbacks' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/PhNkkOieB-8' where name = 'Banded Lateral Walks' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/rVdk_9rwRIM' where name = 'Glute Bridge Hold' and is_global;
