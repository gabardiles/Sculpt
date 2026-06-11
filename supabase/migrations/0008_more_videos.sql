-- 0008_more_videos.sql
--
-- Curated YouTube instruction videos for the remaining 53 global exercises
-- that were not covered by 0003_instruction_videos.sql. URLs use the
-- privacy-enhanced youtube-nocookie.com/embed/ form so the app can embed
-- them in an iframe.
--
-- Each video ID was found via web search against the live YouTube index
-- (June 2026) and chosen from form-focused channels (NASM, Physique
-- Development, Team Evolve, Buff Dudes, ScottHermanFitness / Muscular
-- Strength, Men's Health, Well+Good, OPEX, MedBridge, Jordan Syatt, etc.).
--
-- Idempotent: plain UPDATEs keyed on the unique global exercise name.

-- Hamstrings / hinge
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/aa57T45iFSE' where name = 'Dumbbell Romanian Deadlift' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/DOgPGjztNiE' where name = 'Single-Leg Romanian Deadlift' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/2fHE6zxftYw' where name = 'Stiff-Leg Deadlift' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/0Syp9iyINZ4' where name = 'Good Morning' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/lUH80pneL5w' where name = 'Lying Leg Curl' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/oFxEDkppbSQ' where name = 'Seated Leg Curl' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/sSESeQAir2M' where name = 'Kettlebell Swing' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/cDlOSfu-zHY' where name = 'Sumo Deadlift' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/rXycWnjAUbg' where name = 'Conventional Deadlift' and is_global;

-- Glutes
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/ADgWjz9i42Y' where name = 'Smith Machine Hip Thrust' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/0od5lwWMGV8' where name = 'Barbell Glute Bridge' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/0kx1QOzhTCQ' where name = 'Dumbbell Glute Bridge' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/vYHqQmurSUk' where name = 'Single-Leg Hip Thrust' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/24pvhNOoK80' where name = 'Machine Kickback' and is_global;

-- Lunges / squats
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/C_P3Q-PssvY' where name = 'Reverse Lunge' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/xr9GQeo6lPY' where name = 'Curtsy Lunge' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/B7VQJiVv3xw' where name = 'Forward Lunge' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/NkAlwfIbsa0' where name = 'Smith Machine Split Squat' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/A9QuvCixqsk' where name = 'Deficit Reverse Lunge' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/6mf0oa2GGUc' where name = 'Goblet Squat' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/yoP29LtTdnQ' where name = 'Smith Machine Squat' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/hglQExHCM9Q' where name = 'Hack Squat' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/RL2tjxz0ikw' where name = 'Box Squat' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/QCLWnLNM35U' where name = 'Pendulum Squat' and is_global;

-- Hip abduction / activation
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/UmmBtOG2N_s' where name = 'Side-Lying Hip Abduction' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/6xDr8LvURMc' where name = 'Banded Clamshells' and is_global;

-- Back
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/fnHeovkmkkk' where name = 'Assisted Pull-Up' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/XLoIFFXjFyY' where name = 'Chest-Supported Row' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/QXy1bfxMae0' where name = 'Machine Row' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/eKJUJ2eFPUY' where name = 'Straight-Arm Pulldown' and is_global;

-- Biceps
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/FNvndC4Ov04' where name = 'Hammer Curls' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/5z4y7QRTx1w' where name = 'Cable Curls' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/5NsFLGUf0Fo' where name = 'EZ-Bar Curls' and is_global;

-- Shoulders
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/e5gJP7quyGk' where name = 'Machine Shoulder Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/6Z15_WdXmVw' where name = 'Arnold Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/zpbm-xRHB6k' where name = 'Cable Lateral Raises' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/uh1UO-ieTYQ' where name = 'Machine Lateral Raise' and is_global;

-- Chest
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/xhEhjF5ozuY' where name = 'Dumbbell Bench Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/WDIpL0pjun0' where name = 'Push-Up' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/pLofEAcfsO8' where name = 'Machine Chest Press' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/c1ZX5ZXMQVk' where name = 'Incline Dumbbell Press' and is_global;

-- Triceps
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/AUsSlsBu5eg' where name = 'Overhead Cable Triceps Extension' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/NIWKqcmpBug' where name = 'Skullcrushers' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/e5Gyc1D_BxM' where name = 'Bench Dips' and is_global;

-- Core
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/bxn9FBrt4-A' where name = 'Dead Bug' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/l7OroezzX9k' where name = 'Hanging Knee Raise' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/j6lR4u193gE' where name = 'Ab Wheel Rollout' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/44ND4bOB-T0' where name = 'Side Plank' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/hf00_b2sRdc' where name = 'Hollow Hold' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/qZaMPggxdhg' where name = 'Weighted Decline Sit-Up' and is_global;

-- Calves
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/I1uQtobaNRQ' where name = 'Seated Calf Raise' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/rh8L34lAKC0' where name = 'Smith Machine Calf Raise' and is_global;
update public.exercises set instruction_url = 'https://www.youtube-nocookie.com/embed/8k435cj30gc' where name = 'Leg Press Calf Raise' and is_global;
