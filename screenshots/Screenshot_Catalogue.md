# Screenshot Catalogue 
The purpose of this folder is for planning. The screenshots show a plan/skeleton of the app. 
The colour scheme should be that of the @screenshots/logo/eros_discord_icon.jpg mimicking the colour tones of the app screenshots, but replacing the purpley/red
with the warm orange and white tones with black for text.
Where there is niche background drawings, you need not worry about adding the Drawing, instead just use a background
Use Themes and a coherent 


Screenshot catalogue:
- Logo/Colour Scheme:
  - @screenshots/logo/eros_discord_icon.jpg
    - Shows the apps icon. It also shows the Orange and white colour tones the app should use
- Dates:
  - @screenshots/dates/3BBCEC5E-DE55-41A8-9BDD-730526430ABD.png 
    - Shows the dates tab when there is currently no dates for a user.
    - The screenshot here shows the defined path/route of planned dates and their states.
  - @screenshots/dates/IMG_2260.PNG
    - Shows when a user has a date planned. Profile of user appears, with thumnbail pic + details about date
- Login:
  - @screenshots/login/create-user/8BA764E5-5619-47B6-BB51-C270658D3C33_1_105_c.jpeg
    - Opening page of app
    - Need breeze replaced with muse
    - The screen can simply be the logo @screenshots/logo/eros_discord_icon.jpg for now + text like shown beneath it
    - Start dating button pushes screen @screenshots/login/create-user/C66338AB-087A-4FD1-8A50-1B183B02E8A5_1_105_c.jpeg
    - Globe EN Button opens up language popup menu shown in @screenshots/login/create-user/84623CD3-B81C-46DF-84FD-5F2C81BC72D9_1_105_c.jpeg
  - @screenshots/login/create-user/84623CD3-B81C-46DF-84FD-5F2C81BC72D9_1_105_c.jpeg
    - Pop up when languages icon is pressed in top corner
    - List of all available app languages pop up
    - Selecting different languages will alter local language settings.
    - This value should be cached for a user locally
  - @screenshots/login/create-user/C66338AB-087A-4FD1-8A50-1B183B02E8A5_1_105_c.jpeg
    - Beginning page for both user login + create
    - Will query backend call to send OTP for phone number
  - @screenshots/login/create-user/47AC0BF3-AA2B-4449-8317-7A12EF24CA9E_1_105_c.jpeg
    - Number verification screen, follows @screenshots/login/create-user/C66338AB-087A-4FD1-8A50-1B183B02E8A5_1_105_c.jpeg
    - Shows users number prev inputted
    - Shows input for OTP
    - Shows resend code in X amount of seconds that will allow a resend
    - Invalid input of code = pop up error
    - Success (user exists for number) = fetch profile login
    - Success (No content, no user existing) = push create segment pages
  - @screenshots/login/create-user/0818BA8E-C49E-4657-A7F0-87429222351A.png
    - First page in create user stack
    - Prompts for users name via input text box
    - Progress bar at top of page indicates what page we are on in the process
    - Input text box cleans + validates input checking for SQL injection etc
    - Once valid name inputted, next button becomes available
  - @screenshots/login/create-user/7E4077C0-9A59-4E60-B938-15CC0824CE29.png
    - Location screen
    - Uses location of user if permissions granted OR input location manually via input text box. This can be seen in @screenshots/login/create-user/11483E57-4A96-4518-A342-95B435339F00.png
    - Use nearest known/big city (Might be API integration we can already add for this map and closest feature)
    - Future improvements show how many partners are near by. For now lets just put a placeholder value like 100+ venues
  - @screenshots/login/create-user/11483E57-4A96-4518-A342-95B435339F00.png
    - Same screen as previous
    - Shows manual text input for location
    - When city entered returns a list of potential locations.
    - For the given location selected we will store the cities name and the lat Lon to send to back end
    - Once user has selected from list we can proceed.
  - @screenshots/login/create-user/EABDAE3A-4630-44B2-85B2-E97A280C19E2.png
    - Dating City Selectors
    - Presents a list of cities within the X amount of radius from users selected lat Lon. This is done via call to backend API with lat lon returning list of cities that are available to select from.
    - Atleast one needs to be selected to proceed
    - User can select multiple and then move on as well
  - @screenshots/login/create-user/AAEC2A7B-6A73-467F-8689-04758736101A.png
    - Gender Identity selection
    - Return backend enum values or should they already be in FE? I believe we would need them in the FE anyway just need to ensure sink with BE
    - Enum presents 3 options: Female, Male, Other
  - @screenshots/login/create-user/29A37231-9F7E-4CF8-88F5-F6C4A92CCF01.png
    - Same as above screen, but shown when none of the options is selected so we can’t proceed
  - @screenshots/login/create-user/2759F84B-3B33-460F-A0F6-AED9FFEC0AA2.png
    - Screen presented when gender selected and button pressed to define further, as seen in @screenshots/login/create-user/AAEC2A7B-6A73-467F-8689-04758736101A.png
    - Select from pre defined or submit own description
    - Bottom checkbox to show if gender identity should be shown.
  - @screenshots/login/create-user/F5BCC916-69EC-4805-BC11-BD812A5BFA51.png
    - 3 options: Men, Women, Other. These need to align with BE values
    - Allows multiple to be ticked
  - @screenshots/login/create-user/836BFF48-D008-40B9-A568-2E32E2580C72.png
    - Day, Month, Year input
    - Only 18+ allowed to be inputted
    - Format of DD MM YYYY will be used
    - Value is a permanently displayed field and cannot be hidden
    - Requires valid input to proceed
    - Max age of 120 allowed
  - @screenshots/login/create-user/3501077E-60FD-4AB1-BDE8-BBC133EA7E48.png
    - Shown here is a list of Enum accepted language values that we support
    - Language will be displayed on profile
    - Option to add sign language at the bottom, when pressed displays @screenshots/login/create-user/1C1E3F44-589F-41FD-8AF7-73C3D1E71AFA.png
  - @screenshots/login/create-user/1C1E3F44-589F-41FD-8AF7-73C3D1E71AFA.png
    - Show all available sign language values.
    - None or 1 is allowed to be selected
    - Save button allows user to go back with state stored
  - @screenshots/login/create-user/F6C549FC-FECF-4410-9B00-DDF6001329B2.png
    - Text input field where toggle between FT and CM allowed
    - Only valid heights allowed. Min 3 FT MAX 9 FT
    - If invalid input give pop up sauying invalid and prompt again until valid height inputted
    - This will always be displayed on profile
  - @screenshots/login/create-user/2B95D7A1-BF71-403E-8BFD-7B6733E633D7.png
    - Shows format when height has been inputted
    - Proceed button is press bale now that valid height inputted
  - @screenshots/login/create-user/B9F9ABB6-7BE3-40B3-9160-CA7D48A096BD.png
    - List of all the potential ways they may have found us
    - We can send this data off to backend for metrics to do with Location + Advertising to see how affective etc most of our marketing works as.
  - @screenshots/login/create-user/AD507A8B-D921-47A0-94D5-93959BFCCAD5.png
    - Shows the text input field for other.
    - Ensure text input is validated as real text not injectable and no more than 250 chars min 1 word or (2 chars)
  - @screenshots/login/create-user/4AB7216B-DFC9-4716-9999-72A12357B8BB.png
    - Email text input field
    - Valid email must be inputted
    - Can verify the email.
    - May be used instead of phone number
    - Checkbox for legally allowing us for consenting to receive emails from us
    - Can only proceed when past validation.
  - @screenshots/login/create-user/2B2A66BB-FECA-4ECA-B133-53CC77A34D91.png
    - Finalising page
    - Contains the legal Terms & Conditions
    - The name of user should be displayed. Here in the screenshot Test is the placeholder for user's name
    - See our guidelines should open up a page containing random text data for now
- Match:
  - @screenshots/match/87A5473E-37BE-403B-BBE2-76B03CD76AE6_1_105_c.jpeg
    - Shows the match tab when a batches are present.
    - Potential matchs name, thumbnail, badges, matching traits
    - 2 Actions buttons that will call: /match/action/{matchId} API to backend
    - After action taken card will be removed.
  - @screenshots/match/1C92B78C-52C5-44B3-B72C-6B33A934F181_1_105_c.jpeg
    - Shows the card when all profiles and daily batches have been served. Tells users to come back at 19:00
  - Last 24 hours:
    - @screenshots/match/last-24-hours/C88E1B6A-1B94-45D2-A84B-1EEF6DC223F7.png
      - Shows the 24 hour button on match's tab.
      - When pressed shows the last matches of 24 hours that have an action that can be taken.
      - When pressed calls: /match/last-24 API to backend to fetch the last 24 hour missed matches
    - @screenshots/match/last-24-hours/6F29C101-D725-492C-9F69-0A9232E93E8D.png
      - Shows the 24 hours tab when empty list or no actions are left to be taken
    - @screenshots/match/last-24-hours/C9E9D03A-D14D-40B8-8886-8B4CF1CB4147.png
      - Shows the 24 hours tab when there is data present with a list of user profiles action can be taken upon
    - @screenshots/match/last-24-hours/21DD77A9-0C8F-4521-85B1-4D43C349B54F.png
      - Shows the UserProfile of a potential match that was a previous no. The only option available is a go for drink button
      - The user can re-review the users profile and go for a drink via call: /match/action/{matchId} API to backend
      - Or user will take no action so it will remain as an unsuccessful match
      - When action taken, card removed from list of past 24 hours.
- Users:
  - create-profile:
    - @screenshots/users/create-profile/1F15020C-4606-4494-B042-6E25E65D4313.png
      - The first page displayed when a user has been set up correctly. We now need to create a users profile to be displayed and assist with matching
      - The only required from this page to implement is the text stating about reviewing profiles and getting the profiles setup
      - The button at the bottom should begin the journey of setting up profile
      - When we begin journey we need to create the object that will be sent to BE via POST /users
    - @screenshots/users/create-profile/7366439D-0743-4B0F-B261-7455DCA007F1.png
      - Asking users how they want to date. This is an enum based on BE vaulues: enum class DateIntentions { CASUAL_DATING,SERIOUS_DATING,FRIENDSHIP,NETWORKING,NOT_SURE}
      - The enums should map to buttons as shown in image
      - The top bar shows the progress/page we are on in the create profile progress
      - When selecting value we store this locally for UserProfile, ready to send data for the users endpoint
    - @screenshots/users/create-profile/02DFD182-353E-48F1-9DB2-AAD07E56791C.png
      - Second Screen for having kids
      - Options here correlate to the enum: enum class KidsPreference {
        WANT_KIDS,
        DONT_WANT_KIDS,
        HAVE_KIDS,
        OPEN_TO_KIDS,
        PREFER_NOT_TO_SAY
        }
      - Only one option can be selected
    - @screenshots/users/create-profile/9E6D741C-F92F-4828-B1CF-675E6ED8EACF.png
      - Drinking preference of user
      - Correlates too enum: enum class AlcoholConsumption {
        NEVER,
        SOMETIMES,
        REGULARLY,
        PREFER_NOT_TO_SAY
        }
      - Only one can be selected
    - @screenshots/users/create-profile/446BC802-CBB0-4D66-8D09-C9A328C7753B.png
      - Smoking habits
      - Correlates to enum: enum class SmokingStatus {
        NEVER,
        SOMETIMES,
        REGULARLY,
        QUITTING,
        PREFER_NOT_TO_SAY;
        }
      - Only one can be selected
    - @screenshots/users/create-profile/278ED7CB-8AA4-4990-A13B-1D0F12431AC6.png
      - Education Screen:
      - Correlates to enum: enum class EducationLevel {
        COLLEGE,
        UNIVERSITY,
        APPRENTICESHIP,
        PREFER_NOT_TO_SAY
        }
      - Only one can be selected
    - @screenshots/users/create-profile/A7C87B65-5F8F-4648-9E31-BD6C09779DEF.png
      - Job and study section
      - Top text input box for job
      - Second text input box for study
      - Text input needs to be validated against SQL or code injection attacks
    - @screenshots/users/create-profile/E73ABF64-E138-4BC1-9A2B-8575B6FC21EC.png
      - Interests screen. This screen allows a max and min of how many need to be picked.
      - This correlates too a List<String>, where the String values are derived from the available enum options.
      - The text input section at the top allows for searching for a given enum value in one of the subsections
      - The following screens are subsections for each field shown here
    - @screenshots/users/create-profile/F9D8151D-B02B-4B97-A3E6-C4A6B5F5871C.png
      - Shows the subsection sports for Sports tab in @screenshots/users/create-profile/E73ABF64-E138-4BC1-9A2B-8575B6FC21EC.png
      - Sports should have the enum values: enum class Sport {
        KICK_BOXING,
        GOLF,
        KITE_SURFING,
        ATHLETICS,
        BADMINTON,
        BALLET,
        BASEBALL,
        BASKETBALL,
        BOULDERING,
        BOWLING,
        CLIMBING,
        CRICKET,
        CROSS_TRAINING,
        CYCLING,
        DANCING,
        EXTREME_SPORTS,
        FENCING,
        FITNESS,
        FOOTBALL,
        HANDBALL,
        HOCKEY,
        HORSE_RIDING,
        ICE_SKATING,
        KAYAKING,
        KITESURFING,
        MARTIAL_ARTS,
        MOTORCYCLING,
        MOUNTAINBIKING,
        PADEL,
        PICKLEBALL,
        PILATES,
        ROWING,
        RUGBY,
        RUNNING,
        SUP,
        SAILING,
        SCUBA_DIVING,
        SKATEBOARDING,
        SKIING,
        SNOWBOARDING,
        SPIKEBALL,
        SQUASH,
        SURFING,
        SWIMMING,
        TENNIS,
        VOLLEYBALL,
        YOGA
        }
      - When user selects an activity, on press it is added or removed from list based on its current state
      - When selected alter the colour to a grey to indicate selection of box.
    - @screenshots/users/create-profile/DBF8AB38-1124-425E-B71B-3BDBF0F6E06E.png
      - Foods and Drink interest
      - Correlates too enum: enum class FoodAndDrink {
        BBQ,
        BARBECUE,
        BEER,
        BIRYANI,
        BOBA,
        CHAMPAGNE,
        CHARCUTERIE,
        CHEESE,
        CHOCOLATE,
        COCKTAILS,
        COFFEE,
        CRAFT_BEERS,
        CURRY,
        EMPANADA,
        FALAFEL,
        HOT_POT,
        JOLLOF,
        MATCHA,
        PASTA,
        PIZZA,
        PUBS,
        RAMEN,
        ROTI,
        SUSHI,
        TAPAS,
        TEA,
        WHISKEY,
        WINE
        }
      - When user selects an activity, on press it is added or removed from list based on its current state
      - When selected alter the colour to a grey to indicate selection of box.
    - @screenshots/users/create-profile/B9B554CC-8902-400D-BA83-E0460202E9D7.png
      - Creative screen
      - Correlates to the enum: enum class Creative {
        ACTING,
        COMPOSING_MUSIC,
        CRAFTS,
        DIY,
        DESIGN,
        DRAWING,
        FASHION,
        KNITTING,
        PAINTING,
        PHOTOGRAPHY,
        PLAYING_INSTRUMENTS,
        POETRY,
        POTTERY,
        SEWING,
        SINGING,
        WRITING
        }
      - When user selects an activity, on press it is added or removed from list based on its current state
      - When selected alter the colour to a grey to indicate selection of box.
    - @screenshots/users/create-profile/881D2727-6446-47F5-BCC2-43CD32DB36C6.png
      - Entertainment Tab for interest
      - Correlates to the enum: enum class Entertainment {
        READING,
        ANIME,
        BOARD_GAMES,
        CARTOONS,
        CHESS,
        COMEDY,
        COMICS,
        DISNEY,
        DOCUMENTARIES,
        FANTASY,
        GAMING,
        HORROR,
        MEMES,
        MOVIES,
        MUSICALS,
        NETFLIX,
        PODCASTS,
        PUZZLES,
        SCI_FI,
        SITCOMS,
        TRUE_CRIME,
        VINYL_RECORDS,
        YOUTUBE
        }
      - When user selects an activity, on press it is added or removed from list based on its current state
      - When selected alter the colour to a grey to indicate selection of box.
    - @screenshots/users/create-profile/063B6F67-89AB-47BB-81A7-11FFC8C6591C.png
      - Music tab for interests
      - Correlates too enum: enum class MusicGenre {
        AFRO_BEATS,
        BLUES,
        CLASSICAL_MUSIC,
        COUNTRY_MUSIC,
        DJING,
        DANCEHALL,
        DISCO,
        DRUM_AND_BASS,
        DRUMS,
        DUBSTEP,
        EDM,
        FUNK,
        GUITAR,
        HARDSTYLE,
        HIPHOP,
        HOUSE,
        INDIE_MUSIC,
        JAZZ,
        K_POP,
        LATIN_MUSIC,
        METAL,
        PIANO,
        POP_MUSIC,
        PUNK,
        R_AND_B,
        RAP,
        REGGAE,
        REGGAETON,
        ROCK,
        SALSA,
        SOUL,
        TECHNO
        }
      - When user selects an activity, on press it is added or removed from list based on its current state
      - When selected alter the colour to a grey to indicate selection of box.
    - @screenshots/users/create-profile/59AD97C6-6B96-4687-B06C-C28CF39CA052.png
      - Activities tab for interests page
      - Correlates too enum: enum class Activity {
        CITY_TRIPS,
        OUTDOORS,
        PUB_QUIZ,
        WELLNESS,
        BACKPACKING,
        BAKING,
        BEACH,
        CAMPING,
        CONCERTS,
        COOKING,
        COSPLAY,
        DINING_OUT,
        DINNER_PARTIES,
        ESCAPE_ROOMS,
        FESTIVALS,
        HAVING_DRINKS,
        HIKING,
        KARAOKE,
        MEDITATION,
        MOUNTAINS,
        MUSEUM,
        PARTY,
        RESORT_VACATIONS,
        ROAD_TRIPS,
        SAUNA,
        SHOPPING,
        TAKING_A_WALK,
        THRIFTING
        }
      - When user selects an activity, on press it is added or removed from list based on its current state
      - When selected alter the colour to a grey to indicate selection of box.
    - @screenshots/users/create-profile/2A5D9D2F-8D3C-4486-BEF9-3443CB9D0408.png
      - Interests tab for interest page
      - Correlates to enum: enum class Interest {
        ENTREPRENEURSHIP,
        FORMULA_1,
        LANGUAGES,
        AI,
        ANIMALS,
        ARCHITECTURE,
        ART,
        BIOLOGY,
        CARS,
        CATS,
        CINEMA,
        DOGS,
        FINANCE,
        HISTORY,
        HORSES,
        NATURE,
        PERSONAL_DEVELOPMENT,
        PHILOSOPHY,
        PLANTS,
        POLITICS,
        PROGRAMMING,
        PSYCHOLOGY,
        SCIENCE,
        SNEAKERS,
        SUSTAINABILITY,
        TATTOOS,
        TECH,
        THEATRE
        }
      - When user selects an activity, on press it is added or removed from list based on its current state
      - When selected alter the colour to a grey to indicate selection of box.
    - @screenshots/users/create-profile/F385FEFE-708E-434A-9D6F-DCC3B230A2E2.png
      - How would you describe yourself screen
      - Text input field allows searching in the subsection of following screens enums
      - There is no personality type (MBTI). This can be removed and not implemented
      - Lifestyle has been combined with Trait enum.
      - The tab Personality Trait correlates to enum: enum class Trait {
        ADVENTUROUS,
        AMBITIOUS,
        SPONTANEOUS,
        ENERGETIC,
        HONEST,
        WITTY,
        FAMILY_ORIENTATED,
        MINIMALIST,
        HEALTH_CONSCIOUS,
        COMPETITION_SEEKER,
        AMBIVERT,
        CALM,
        CARING,
        CHAOTIC,
        CREATIVE,
        CURIOUS,
        DEEP_THINKER,
        DREAMER,
        EMPATHETIC,
        EXTRAVERT,
        FLEXIBLE,
        GENEROUS,
        GO_GETTER,
        INTROVERT,
        KIND,
        LISTENER,
        OPEN_MINDED,
        OPTIMISTIC,
        ORGANIZED,
        OUTGOING,
        PASSIONATE,
        PATIENT,
        PLAYFUL,
        PRACTICAL,
        QUIET,
        RELIABLE,
        RESERVED,
        ROMANTIC,
        SARCASTIC,
        SENSITIVE,
        SERIOUS,
        SHY,
        THOUGHTFUL,
        TRADITIONAL
        }
      - Star sign correlates to enum: enum class StarSign {
        ARIES,
        TAURUS,
        GEMINI,
        CANCER,
        LEO,
        VIRGO,
        LIBRA,
        SCORPIO,
        SAGITTARIUS,
        CAPRICORN,
        AQUARIUS,
        PISCES
        }
      - When a user selects. Display the currently selected with a dark background. And show selected at top of screen @screenshots/users/create-profile/D1846925-86A5-4AEF-93BE-37737041F8F0.png shows this as an example
      - Max 10 Min 3 required to proceed
    - @screenshots/users/create-profile/5A0A4901-671B-40D4-8071-C221FAE190A0.png
      - Shows the QA section.
      - A selection box is possible, when pressed @screenshots/users/create-profile/2773081D-DBB1-4E02-85A9-F9C8DAA60F46.png is shown
      - A user can have 1 <= QA <= 3
      - 1 must be present to proceed
    - @screenshots/users/create-profile/2773081D-DBB1-4E02-85A9-F9C8DAA60F46.png
      - Shows the Question screen
      - 4 tabs: Interests, Personal, Fun, Ambitious
      - Questions correlate to the enum: enum class PredefinedQuestion {
        // Fun category
        LAST_MEAL_EVER,
        SECOND_DATE_IDEA,
        PERFECT_HOLIDAY,
        RAINY_SUNDAY_ACTIVITY,
        MYTHICAL_CREATURE_RELATE,
        WEIRDEST_FOOD_COMBO,
        NEVER_FAILS_TO_LAUGH,
        LIFE_THEME_SONG,
        MOST_BEAUTIFUL_VIEW,
        SUPERPOWER_FOR_FUN,
        DINNER_WITH_3_FAMOUS,

        Ambitions category
        WANT_TO_LEARN,
        DREAM_JOB_NO_MONEY,
        LIFE_GOAL,
        PROUD_OF,
        WISH_REALLY_GOOD_AT,
        CHALLENGE_SURPRISED_BEATING,
        RANDOM_BUCKET_LIST,
        IDEAL_PLACE_TO_LIVE,
        LOOKING_FORWARD_TO,
        POINTLESS_SKILL_PROUD_OF,
    
        // Interests category
        TALK_ABOUT_FOR_HOURS,
        READING_AT_MOMENT,
        FAVOURITE_MUSIC_ARTIST,
        FAVOURITE_BOOK_MOVIE_TV,
        THINGS_GIVE_JOY,
        EVERYONE_SHOULD_TRY,
        CURRENTLY_OBSESSED_SONG,
        OBSCURE_FACT_KNOW,
        ACTIVITY_LOSE_MYSELF_IN,
        FICTIONAL_CHARACTER_RELATE,
        NICHE_RABBIT_HOLE,
    
        // Personal category
        UNUSUAL_FIND_ATTRACTIVE,
        CORE_VALUES,
        RANDOM_FACTS,
        MOST_AWKWARD_MOMENT,
        PERSONAL_MOTTO,
        FAVOURITE_TATTOO_STORY,
        WHAT_HOME_MEANS,
        BRINGS_OUT_INNER_CHILD,
        COMPLIMENT_NEVER_FORGOTTEN,
        FRIENDS_COME_TO_ME_FOR,
        EMOJI_CAPTURES_ENERGY,
        LOOKING_FOR,
        RELATIONSHIP_GOALS;
    
        fun getDisplayText(): String = when (this) {
        LAST_MEAL_EVER -> "My last meal ever would be"
        SECOND_DATE_IDEA -> "If I could organize our second date, we would"
        PERFECT_HOLIDAY -> "My perfect holiday"
        RAINY_SUNDAY_ACTIVITY -> "What I like to do on a rainy Sunday"
        MYTHICAL_CREATURE_RELATE -> "The mythical creature I relate to most"
        WEIRDEST_FOOD_COMBO -> "The weirdest food combination I enjoy"
        NEVER_FAILS_TO_LAUGH -> "This never fails to make me laugh"
        LIFE_THEME_SONG -> "If my life had a theme song, it would be"
        MOST_BEAUTIFUL_VIEW -> "The most beautiful view I have ever seen"
        SUPERPOWER_FOR_FUN -> "A superpower I'd like to have just for fun"
        DINNER_WITH_3_FAMOUS -> "I'd host dinner for these 3 famous people"
        WANT_TO_LEARN -> "Something I still want to learn"
        DREAM_JOB_NO_MONEY -> "My dream job if money didn't matter"
        LIFE_GOAL -> "A life goal of mine"
        PROUD_OF -> "What I'm proud of"
        WISH_REALLY_GOOD_AT -> "Something I wish I was really good at"
        CHALLENGE_SURPRISED_BEATING -> "A challenge I surprised myself by beating"
        RANDOM_BUCKET_LIST -> "The most random thing on my bucket list"
        IDEAL_PLACE_TO_LIVE -> "My ideal place to live"
        LOOKING_FORWARD_TO -> "Something I'm currently looking forward to"
        POINTLESS_SKILL_PROUD_OF -> "A pointless skill I'm oddly proud of"
        TALK_ABOUT_FOR_HOURS -> "Something I could talk about for hours"
        READING_AT_MOMENT -> "What I'm reading at the moment"
        FAVOURITE_MUSIC_ARTIST -> "My favourite music artist or band"
        FAVOURITE_BOOK_MOVIE_TV -> "My favourite book/movie/tv series"
        THINGS_GIVE_JOY -> "Things that give me joy"
        EVERYONE_SHOULD_TRY -> "What everyone should try at least once"
        CURRENTLY_OBSESSED_SONG -> "The song I'm currently obsessed with"
        OBSCURE_FACT_KNOW -> "The most obscure fact I know"
        ACTIVITY_LOSE_MYSELF_IN -> "An activity I lose myself in"
        FICTIONAL_CHARACTER_RELATE -> "The fictional character I relate to most"
        NICHE_RABBIT_HOLE -> "A niche rabbit hole that fascinates me"
        UNUSUAL_FIND_ATTRACTIVE -> "Something unusual I find attractive in a person"
        CORE_VALUES -> "My core values"
        RANDOM_FACTS -> "Random facts about me"
        MOST_AWKWARD_MOMENT -> "Most awkward moment of my life"
        PERSONAL_MOTTO -> "My personal motto"
        FAVOURITE_TATTOO_STORY -> "The story behind my favourite tattoo"
        WHAT_HOME_MEANS -> "What 'home' means to me"
        BRINGS_OUT_INNER_CHILD -> "What brings out my inner child"
        COMPLIMENT_NEVER_FORGOTTEN -> "A compliment I've never forgotten"
        FRIENDS_COME_TO_ME_FOR -> "Friends always come to me for"
        EMOJI_CAPTURES_ENERGY -> "The emoji(s) that captures my energy best"
        LOOKING_FOR -> "I'm looking for"
        RELATIONSHIP_GOALS -> "My relationship goals"
        }}
    - @screenshots/users/create-profile/CCD90428-DCE2-455B-A3A7-2EC6DC21F1C8.png
      - Shows a Question selected with the text box for answering
      - Text box should be cleaned and validated against SQL or injection attacks
      - Answers should be no more than 150 characters long, and minimum 1 word or 2 chars
      - Save answer button should append to the QA list of a user locally.
    - @screenshots/users/create-profile/CDCD6B62-A04F-4222-B478-A4D29E198C6E.png
      - Shows the QA section, with a QA box present
      - QA box main text is Question, Text beneath is the answer supplied
      - Once max QA been reached, add another question button should be removed from user
      - Once min 1 answered next button can be proceeded
      - Next button should make a call to BE via: /users/qa/me/collection
    - @screenshots/users/create-profile/9D077F6E-F156-4B54-9297-37EC45AE7D10.png
      - Section focuses on Pictures. Correlating to the Photos tag in documentation.yaml
      - User is prompted to Add a thumbnail/profile picture
      - Upon pressing add photo button, phones photo library should pop up. If user hasnt given permissions yet, then this is where we get permissions to access photos, this  can be seen in @screenshots/users/create-profile/55C449A3-E330-435C-B630-12A4B08FD342.png
    - @screenshots/users/create-profile/55C449A3-E330-435C-B630-12A4B08FD342.png
      - Phones native photo library opens to allow selection of images once user given permission
    - @screenshots/users/create-profile/B3F7C09E-4E3D-4DD4-BBB8-42DE6AB0C2D7.png
      - Once image selected a caption can be applied via pressing select caption. This will open @screenshots/users/create-profile/80DC933A-0EDC-479E-BEE5-443A0174135A.png
      - If user doesn't like the image then change photo can be pressed. This will reopen @screenshots/users/create-profile/55C449A3-E330-435C-B630-12A4B08FD342.png to reselect a new image
      - If a user is happy with is, then the continue button can be pressed. The image and its info will be stored in a list locally.
    - @screenshots/users/create-profile/80DC933A-0EDC-479E-BEE5-443A0174135A.png
      - Caption page
      - Will display list of potential captions
      - For now this isnt implemented so we will simply use dummy data. After it will correlate to enum in BE
      - Once a caption selected, return to prev page with caption stored
    - @screenshots/users/create-profile/31A175B9-8404-48F4-B608-8C751E1D03EF.png
      - A page to show all photo selections, where the first is the thumnbail/profile pic prev selected
      - Pressing on any of the Picture slots will open the @B3F7C09E-4E3D-4DD4-BBB8-42DE6AB0C2D7.png as before to select and edit pic
      - A min of 3 and a max of 6 pics can be selected
      - The Complete Profile Button is pressible if this requirement is met.
      - For every picture we will follow the API path: /users/me/photos/presigned-url and then /users/me/photos . Where we get a presigned url first, then we upload  directly to that.
    - @screenshots/users/create-profile/14FD30F8-F075-4743-ACE8-32CEF8978C75.png
      - Shows the photo screen when 5/6 images have been provided
      - Continue button is now pressable due to requirements met with valid pics
    - @screenshots/users/create-profile/6F692A85-9439-4D16-BC71-1FC49E6EB3D1_1_105_c.jpeg
      - Shows the preview page of what will be seen publicly to other users. This will correlate to the value returned from /users/id/{id}/public
      - Once user has ticked box to agree that the data will be published to others then we can continue.
      - If back button is pressed then we will return to the Photo selction screen @screenshots/users/create-profile/14FD30F8-F075-4743-ACE8-32CEF8978C75.png where user can alter pics.
    - @screenshots/users/create-profile/A23E92F9-0A22-4216-9D1F-CAFE761F6C6F.png
      - Final screen once user has confirmed data is correct
      - When start dating occurs, we will go into the app.
      - While we create profile in backend, when start dating is pressed, if we are still creating profile, give a prompt saying give us a moment while we set up your profile and get your potential matches ready
      - Once this is complete we go into apps default look, which should be that of the Match tab.
  - public-profile
    - @screenshots/users/public-profile
      - This shows the inspiration of how a public users profile will look.
      - Photos should not be scrollable horizontally, onPress they should do nothing
      - This encourages users to scroll vertically
      - Photos, Questions, Hobbies/Interests are seen when scrolling.
      - The thumbnail picture is at the Top as seen in @screenshots/users/public-profile/IMG_2511.PNG
      - After this we should show the information:
        - Name, Gender, Height, Sexual Orientation. These can be seen in @screenshots/users/public-profile/IMG_2512.PNG @screenshots/users/public-profile/IMG_2513.PNG @screenshots/users/public-profile/IMG_2514.PNG
      - The rest show the scrolling order.
      - We should place hobbies and interests near the top PublicProfileDTO is the essential mapping
      - PublicProfileDetailsDTO is the additional jazz of the profile