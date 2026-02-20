All frontend style rules for our project

- use tailwind for all styling
- never use bg-zinc of any kind, if you want to acheive a layour effect with the backgrounds always use bg/white of some kind, the most popular one that we use is bg-white/5, but for more subtle things you can decrease the white opacity and do things like bg-white/[.025]
  - all in all, to achieve a "layered" effect for our frontend you should use a white backend with different opacity values in tailwind, these values can range anywhere from .01 to .2, and no change is too small
  - also, whenever you use a bg-white/{some value for opacity}, to really help achieve that layered effect you should pair this with a 1 pixel border with double the opacity of the background, so bg-white/5 and border border-white/10, or bg-white/[.02] and border border-white/[.04], and things like this
- use lucide-react icons for all icons
- always use tracking-wide for all text, use either font-bold or font-semibold for all text inside of buttons
- never specify the font to use, we have defined this in our central layout folder
- our theme for the website is typically dark themed and red, when using red colors in tailwind use anything from red-500 to red-700, nothing outside of this, you CAN change the opacity though where necessary inside of these red shades
  - for any type of coloring that you add, make sure that it is red themed and is the value of the red accents above
- you should use framer motion to animate things (initial animations, hover, exit, etc), however the one animation that I do not like to use is when you change the scale of a component when hovering. You can use framer motion for anything else other than this
- never use zinc for the text color either, if you want more subtle text always use a decreased opacity version of white, ex: text-white/50 or text-white/40 or text-white/20
- never use uppercase for styling on text, never explicity set the font style of the text, for subtle text coloring use either text-white/40,30, or 20
- for regular subtitle/small or extra small text the boldness of the text should be font-medium and tracking-wide, for all headings/titles/font inside of buttons/clickable links this font should be either font-bold or font-semibold still with tracking-wide
- the default animation for all buttons is that when the use hovers one either the inset shadow and background opacity is slightly increased (if it has inset shadow), or the opacity is decreased (if the background is a color), you should also make sure that these hover animations have a 300 millisecond transition
- if there is a situation where there is a scrollbar present, do not use the default styling of the scrollbar, you should make it more subtle on a dark screen (default has white background and is very bright)


Shadowing:

- shadows are a very important in the frontend design, but there is a specific way that we build shadows into our frontend design

- below is how we use them for specific components/widgets inside of our frontend
- colored buttons:
  - firstly if we have a colored button there should be two types of shadows: a subtle shadow that reflects the color of the button and a subtle white inset shadow that adds a "layering" effect to the button, below I will provide you some examples of each (note you dont have to copy these exactly but they are good reference points), and obviously you will have to combine the two types of shadow into 1 shadow tailwind classname:
    - all keep in mind th opacity and pixel values that I am using below
  - example inset shadow:
    - shadow-[inset_0_0_8px_rgba(255,255,255,.2)]
    - shadow-[inset_0_0_15px_rgba(255,255,255,.15)]
    - shadow-[inset_0_0_3px_rgba(255,255,255,.2), inset_0_0_17px_rgba(255,255,255,.075)]

  - example outer shadow: (red themed)
    - shadow-[0_0_25px_rgba(255,0,0,.2)]
    - shadow-[0_5px_20px_rgba(255,0,0,.15)]
    - note, only use these outter shadows for buttons, I do not want you to use red themed outer shadows for anything else, also if you are going to use a red shadow for ANYTHING than the pixel values should be 255,0,0

- besides colored button, there are also other scenarios where it is appropriate to use shadows. Note, for all of the below situations, for the examples that I give you do not have to copy it exactly, but it should be used as a rough guide and you should use similiar shadows for the situation if you find youself in it. below is the common utility of shadows that we have

- using shadows either as or to enhance borders:
  - these are shadows that are very subtle but discrete in the sense that they are not alot of pixels but you can actuall see them, you can either use them as a border directly or ontop of a border to enhance the border
  - examples: shadow-[inset_0_0_3px_rgba(255,255,255,.2)], shadow-[inset_0_0_5px_rgba(255,255,255,.15)], shadow-[inset_0_0_4px_rgba(255,255,255,.3)]
  - note, if you use the shadow as a border, the opacity value should be a little bit higher

- single layered shadows
  - for our medium sizes containers, modals, popups, or even prominant buttons, we can choose to include "single layered shadows" into these components, you should not include these everywhere, but where it make sense you can add these to our frontend elements. These are essentially aimed at being "subtle layered shadows" that are shadows but are not too strong, and they use two to three layered inset shadows
  - examples: shadow-[inset_0_0_6px_rgba(255,255,255,.15),inset_0_0_12px_rgba(255,255,255,.05)],
    shadow-[inset_0_0_4px_rgba(255,255,255,.2),inset_0_0_16px_rgba(255,255,255,.075)],
    shadow-[inset_0_0_8px_rgba(255,255,255,.1),inset_0_0_20px_rgba(255,255,255,.035)],
    shadow-[inset_0_0_5px_rgba(255,255,255,.125),inset_0_0_18px_rgba(255,255,255,.04)]

- Note:
  - all of the above shadow information is mainly for white themed shadows with different opacity values, however if you ever need to enable shadowing for something that is colored on our ui design, then you should apply to same princicples in the aboved coloring
  - if you are Editing components and I am asking you to edit already existing front end unless I explicitly tell you you should not be adding shadows whenever there are not shadows there already.

- icon shadowing:
  - when we have icons with borders I like to have an inset red shadow, it adds to the icon
    - note, this type of shadow is only for icons with borders
      examples: shadow-[inset_0_0_4px_rgba(255,0,0,.6),inset_0_0_17px_rgba(255,0,0,.2)],
      shadow-[inset_0_0_20px_rgba(255,0,0,.2)],
      shadow-[inset_0_0_4px_rgba(255,0,0,.4),inset_0_0_8px_rgba(255,0,0,.2),inset_0_0_20px_rgba(255,0,0,.1)]

padding:

- for small buttons/labers, i prefer py-3 and px-1.5, and these button should have no border
- the roundness of these buttons should be at least rounded-2xl and unless a button is super wide I typically prefer rounder borders (2xl and higher)

main Headings:

- the way that We do main headings for pages can be repeatable and applied to many different scenarios. If a heading is located at the top of the page, it should have a padding top of at least py-40.
  - the heading text should have styles similiar to the following: text-7xl on large screens, white text, and nothing else (keep default boldness and tracking), max width of 4xl
  - we will have description underneath this, styled similiar to text-white/40 font-medium text-sm max-w-3xl text-center
  - apart from this, you can add labels either above or below this text located at next-app/widgets/labels
  - you can also add buttons below from next-app/widgets/buttons
  - this is how we build and develop headings for pages/sections, not headings for sidebars,modals, popups, etc
