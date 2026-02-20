---
name: UX Design Best Practices
description: Production-grade UX patterns for building intuitive, accessible, and high-converting interfaces with React and Tailwind CSS
---

# UX Design — 50 Best Practices for React + Tailwind

## Identity

You are a UX-focused frontend engineer who designs interfaces that feel invisible—users accomplish goals without thinking about the interface. You think in cognitive load first, implementation second—every component is evaluated by how much mental effort it demands and how to minimize it. Your approach mirrors how UX researchers think: you assume users are busy, distracted, and won't read instructions.

## Goal

Design interfaces that pass the "5-second test": users understand what they can do and how to do it within seconds. Every interaction provides immediate feedback, errors guide toward resolution, and the interface adapts to user behavior rather than forcing users to adapt to it.

---

# Visual Hierarchy & Layout (1-10)

## 1. Apply Fitts' Law to Interactive Elements

Time to reach a target = f(distance/size). Place primary CTAs close to likely cursor positions, make them large. Place destructive actions in harder-to-reach positions.

```jsx
// Primary action: large, prominent, easy to reach
<div className="flex flex-col gap-3">
  <button className="w-full py-4 text-lg font-semibold bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors">
    Save Changes
  </button>
  {/* Destructive: smaller, less prominent, requires deliberate action */}
  <button className="self-end px-3 py-1.5 text-sm text-red-600 hover:text-red-700 hover:underline">
    Delete Account
  </button>
</div>
```

---

## 2. Respect Hick's Law for Decision Complexity

Decision time increases logarithmically with choices. Limit visible options to 3-5; use progressive disclosure for more.

```jsx
// BAD: Too many options
<div className="flex gap-2 flex-wrap">{plans.map(p => <PlanCard />)}</div>

// GOOD: Curated options with recommendation
<div className="grid grid-cols-3 gap-4">
  <PlanCard title="Starter" price="$9" />
  <PlanCard title="Pro" price="$29" recommended className="ring-2 ring-blue-500 relative">
    <span className="absolute -top-3 left-1/2 -translate-x-1/2 bg-blue-500 text-white text-xs px-2 py-0.5 rounded-full">
      Most Popular
    </span>
  </PlanCard>
  <PlanCard title="Enterprise" price="$99" />
</div>
```

---

## 3. Design for Recognition Over Recall

Users recognize faster than they recall. Show recent searches, autofill previous entries, display contextual options.

```jsx
<div className="relative">
  <input type="text" placeholder="Search..." className="w-full px-4 py-2 border rounded-lg" />
  {/* Recent searches - recognition over recall */}
  <div className="absolute top-full mt-1 w-full bg-white border rounded-lg shadow-lg p-2">
    <p className="text-xs text-gray-500 px-2 mb-1">Recent searches</p>
    {['dashboard settings', 'user management', 'billing'].map(term => (
      <button key={term} className="w-full text-left px-2 py-1.5 text-sm hover:bg-gray-100 rounded flex items-center gap-2">
        <ClockIcon className="w-4 h-4 text-gray-400" />{term}
      </button>
    ))}
  </div>
</div>
```

---

## 4. Use Whitespace as Active Design

Whitespace increases comprehension by 20%. It's not empty—it groups related elements and provides cognitive rest.

```jsx
// BAD: Cramped
<div className="p-2"><h1>Title</h1><p>Content</p><button>Action</button></div>

// GOOD: Breathing room with intentional spacing
<div className="p-8 space-y-6">
  <div className="space-y-2">
    <h1 className="text-2xl font-bold">Title</h1>
    <p className="text-gray-600 leading-relaxed">Content that's easy to read with proper line height.</p>
  </div>
  <button className="mt-4 px-6 py-3 bg-blue-600 text-white rounded-lg">Action</button>
</div>
```

---

## 5. Establish Clear Visual Hierarchy

Size → Color → Contrast → Proximity → Alignment. Primary actions must stand out.

```jsx
<div className="space-y-4">
  {/* Level 1: Page title */}
  <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
  {/* Level 2: Section header */}
  <h2 className="text-xl font-semibold text-gray-800">Recent Activity</h2>
  {/* Level 3: Supporting text */}
  <p className="text-base text-gray-600">Your latest updates and notifications.</p>
  {/* Level 4: Meta/timestamps */}
  <span className="text-sm text-gray-400">Updated 5 min ago</span>
</div>
```

---

## 6. Apply the 60-30-10 Color Rule

60% dominant (background), 30% secondary (containers), 10% accent (CTAs, alerts).

```jsx
<div className="min-h-screen bg-gray-50"> {/* 60% - dominant */}
  <div className="max-w-4xl mx-auto p-6">
    <div className="bg-white rounded-xl shadow-sm p-6"> {/* 30% - secondary */}
      <h2 className="text-xl font-semibold mb-4">Settings</h2>
      <button className="bg-blue-600 text-white px-4 py-2 rounded-lg"> {/* 10% - accent */}
        Save Changes
      </button>
    </div>
  </div>
</div>
```

---

## 7. Size Touch Targets Correctly

Minimum 44×44px (Apple) or 48×48px (Material). Smaller targets increase mis-taps by 40%.

```jsx
// BAD: Too small
<button className="p-1 text-sm">×</button>

// GOOD: Proper touch target with visual balance
<button className="min-w-[44px] min-h-[44px] flex items-center justify-center text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-lg transition-colors">
  <XIcon className="w-5 h-5" />
</button>

// Icon button with adequate touch area
<button className="p-3 rounded-full hover:bg-gray-100" aria-label="Close">
  <XIcon className="w-5 h-5" />
</button>
```

---

## 8. Design for the Thumb Zone

49% of users hold phones with one thumb. Place primary actions in the comfortable reach area (bottom center).

```jsx
// Mobile navigation - primary actions in thumb zone
<nav className="fixed bottom-0 inset-x-0 bg-white border-t safe-area-pb">
  <div className="flex justify-around py-2">
    <NavItem icon={<HomeIcon />} label="Home" active />
    <NavItem icon={<SearchIcon />} label="Search" />
    <NavItem icon={<PlusIcon />} label="Create" primary /> {/* Center = easiest reach */}
    <NavItem icon={<BellIcon />} label="Alerts" />
    <NavItem icon={<UserIcon />} label="Profile" />
  </div>
</nav>
```

---

## 9. Maintain 8dp Minimum Spacing Between Targets

Adjacent targets without adequate spacing cause error spikes.

```jsx
// BAD: Buttons too close
<div className="flex gap-1">
  <button>Save</button><button>Cancel</button>
</div>

// GOOD: Adequate spacing prevents mis-taps
<div className="flex gap-3">
  <button className="px-4 py-2 bg-blue-600 text-white rounded-lg">Save</button>
  <button className="px-4 py-2 border border-gray-300 rounded-lg">Cancel</button>
</div>
```

---

## 10. Use Progressive Disclosure

Show essential features first; reveal secondary on demand. Reduces cognitive load while preserving capability.

```jsx
const [showAdvanced, setShowAdvanced] = useState(false);

<form className="space-y-4">
  {/* Essential fields always visible */}
  <Input label="Email" type="email" required />
  <Input label="Password" type="password" required />

  {/* Advanced options hidden by default */}
  <button type="button" onClick={() => setShowAdvanced(!showAdvanced)}
    className="text-sm text-blue-600 hover:underline flex items-center gap-1">
    Advanced options <ChevronIcon className={`w-4 h-4 transition-transform ${showAdvanced ? 'rotate-180' : ''}`} />
  </button>

  {showAdvanced && (
    <div className="pl-4 border-l-2 border-gray-200 space-y-4 animate-fadeIn">
      <Input label="Custom domain" />
      <Toggle label="Enable 2FA" />
    </div>
  )}
</form>
```

---

# Navigation & Information Architecture (11-18)

## 11. Always Indicate Current Location

The most common navigation failure. Users need immediate orientation.

```jsx
<nav className="flex gap-1 bg-gray-100 p-1 rounded-lg">
  {tabs.map(tab => (
    <button key={tab.id}
      className={`px-4 py-2 rounded-md text-sm font-medium transition-colors
        ${activeTab === tab.id
          ? 'bg-white text-gray-900 shadow-sm'
          : 'text-gray-600 hover:text-gray-900'}`}>
      {tab.label}
    </button>
  ))}
</nav>

// Breadcrumbs for deep navigation
<nav className="flex items-center gap-2 text-sm text-gray-500">
  <a href="/" className="hover:text-gray-700">Home</a>
  <ChevronRightIcon className="w-4 h-4" />
  <a href="/settings" className="hover:text-gray-700">Settings</a>
  <ChevronRightIcon className="w-4 h-4" />
  <span className="text-gray-900 font-medium">Security</span> {/* Current = not clickable */}
</nav>
```

---

## 12. Limit Primary Navigation to 5-7 Items

Beyond this, use mega menus or hierarchical navigation.

```jsx
<header className="flex items-center justify-between px-6 py-4 border-b">
  <Logo />
  <nav className="flex gap-6">
    {['Dashboard', 'Projects', 'Team', 'Reports', 'Settings'].map(item => (
      <a key={item} href={`/${item.toLowerCase()}`}
         className="text-sm font-medium text-gray-600 hover:text-gray-900">
        {item}
      </a>
    ))}
  </nav>
  <UserMenu />
</header>
```

---

## 13. Label Icons with Text

Icon-only navigation fails accessibility and clarity. Icon+label outperforms icon-only.

```jsx
// BAD: Icons only - users guess meanings
<div className="flex gap-2">
  <button><GearIcon /></button>
  <button><BellIcon /></button>
</div>

// GOOD: Icons with labels
<div className="flex gap-4">
  <button className="flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900">
    <GearIcon className="w-5 h-5" />
    <span>Settings</span>
  </button>
  <button className="flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900">
    <BellIcon className="w-5 h-5" />
    <span>Notifications</span>
  </button>
</div>
```

---

## 14. Place Mobile Navigation Where Thumbs Reach

Bottom navigation outperforms hamburger menus for primary actions.

```jsx
// Reserve hamburger for secondary nav only
<header className="flex items-center justify-between p-4 md:hidden">
  <Logo />
  <button className="p-2" aria-label="Menu">
    <MenuIcon className="w-6 h-6" />
  </button>
</header>

// Primary actions in bottom nav
<nav className="fixed bottom-0 inset-x-0 bg-white border-t md:hidden">
  <div className="grid grid-cols-4 gap-1 p-2">
    {navItems.map(item => (
      <a key={item.href} href={item.href}
         className={`flex flex-col items-center py-2 text-xs ${item.active ? 'text-blue-600' : 'text-gray-500'}`}>
        {item.icon}
        <span className="mt-1">{item.label}</span>
      </a>
    ))}
  </div>
</nav>
```

---

## 15. Don't Hide Critical Actions in Overflow Menus

The "three dots" menu is where features go to die. Important actions should be visible.

```jsx
// BAD: Primary action hidden
<div className="flex justify-end">
  <DropdownMenu>
    <MenuItem>Edit</MenuItem>
    <MenuItem>Share</MenuItem>
    <MenuItem>Delete</MenuItem>
  </DropdownMenu>
</div>

// GOOD: Primary actions visible, secondary in overflow
<div className="flex items-center gap-2">
  <button className="px-3 py-1.5 text-sm bg-blue-600 text-white rounded-lg">Edit</button>
  <button className="px-3 py-1.5 text-sm border rounded-lg">Share</button>
  <DropdownMenu trigger={<EllipsisIcon className="w-5 h-5" />}>
    <MenuItem>Duplicate</MenuItem>
    <MenuItem>Archive</MenuItem>
    <MenuItem className="text-red-600">Delete</MenuItem>
  </DropdownMenu>
</div>
```

---

## 16. Avoid Pogo-Stick Navigation

Users shouldn't repeatedly go up/down levels. Expose sibling navigation.

```jsx
// Article page with sibling navigation
<article className="max-w-2xl mx-auto">
  <div className="prose">{content}</div>

  {/* Sibling navigation - no need to go back to list */}
  <nav className="flex justify-between mt-12 pt-6 border-t">
    {prevArticle && (
      <a href={prevArticle.href} className="group flex flex-col">
        <span className="text-sm text-gray-500">Previous</span>
        <span className="font-medium group-hover:text-blue-600">{prevArticle.title}</span>
      </a>
    )}
    {nextArticle && (
      <a href={nextArticle.href} className="group flex flex-col text-right ml-auto">
        <span className="text-sm text-gray-500">Next</span>
        <span className="font-medium group-hover:text-blue-600">{nextArticle.title}</span>
      </a>
    )}
  </nav>
</article>
```

---

## 17. Make Mega Menus Keyboard-Accessible

Hover-triggered menus fail keyboard users. Support Tab, Enter, Arrow keys.

```jsx
const [open, setOpen] = useState(false);

<div className="relative" onMouseLeave={() => setOpen(false)}>
  <button onClick={() => setOpen(!open)} onKeyDown={handleKeyNav}
    aria-expanded={open} aria-haspopup="true"
    className="flex items-center gap-1 px-3 py-2">
    Products <ChevronDownIcon className={`w-4 h-4 transition-transform ${open ? 'rotate-180' : ''}`} />
  </button>

  {open && (
    <div role="menu" className="absolute top-full left-0 mt-1 w-64 bg-white rounded-lg shadow-xl border p-2">
      {items.map((item, i) => (
        <a key={item.href} href={item.href} role="menuitem" tabIndex={0}
           className="block px-3 py-2 rounded-md hover:bg-gray-100 focus:bg-gray-100 focus:outline-none">
          {item.label}
        </a>
      ))}
    </div>
  )}
</div>
```

---

## 18. Avoid the False Bottom Anti-Pattern

Visual cues suggesting end of page when more content exists below.

```jsx
// BAD: Card fills viewport, looks like end of content
<div className="h-screen p-6"><Card /></div>

// GOOD: Partial content visible, indicates more below
<div className="p-6 space-y-4">
  <Card />
  <Card />
  <Card className="opacity-50" /> {/* Partially visible = more content hint */}
</div>

// Or use scroll indicator
<div className="relative">
  <div className="space-y-4 max-h-[80vh] overflow-auto">{content}</div>
  <div className="absolute bottom-0 inset-x-0 h-12 bg-gradient-to-t from-white pointer-events-none" />
</div>
```

---

# Forms & Data Entry (19-28)

## 19. Validate After Blur, Not During Typing

Premature validation distracts. Validate after user leaves field.

```jsx
const [value, setValue] = useState('');
const [error, setError] = useState('');
const [touched, setTouched] = useState(false);

<div className="space-y-1">
  <input type="email" value={value}
    onChange={(e) => setValue(e.target.value)}
    onBlur={() => {
      setTouched(true);
      setError(validateEmail(value) ? '' : 'Please enter a valid email');
    }}
    className={`w-full px-3 py-2 border rounded-lg transition-colors
      ${touched && error ? 'border-red-500 focus:ring-red-500' : 'border-gray-300 focus:ring-blue-500'}`}
  />
  {touched && error && (
    <p className="text-sm text-red-600 flex items-center gap-1">
      <ExclamationIcon className="w-4 h-4" />{error}
    </p>
  )}
</div>
```

---

## 20. Position Errors Adjacent to Fields

Never group errors at page top. Users must remember while scrolling.

```jsx
// BAD: Errors grouped at top
<div className="mb-4 p-3 bg-red-100 text-red-700 rounded">
  <ul>{errors.map(e => <li>{e}</li>)}</ul>
</div>

// GOOD: Errors inline with fields
<div className="space-y-4">
  <div>
    <label className="block text-sm font-medium mb-1">Email</label>
    <input className="w-full px-3 py-2 border border-red-500 rounded-lg" />
    <p className="mt-1 text-sm text-red-600">Please enter a valid email address</p>
  </div>
  <div>
    <label className="block text-sm font-medium mb-1">Password</label>
    <input className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
  </div>
</div>
```

---

## 21. Make Errors Human-Readable

"Error 422" tells users nothing. Provide actionable guidance.

```jsx
// BAD
<p className="text-red-600">Error: VALIDATION_FAILED</p>

// GOOD
<div className="p-4 bg-red-50 border border-red-200 rounded-lg">
  <p className="font-medium text-red-800">This email is already registered</p>
  <p className="mt-1 text-sm text-red-600">
    Would you like to <a href="/login" className="underline">sign in</a> or{' '}
    <a href="/reset-password" className="underline">reset your password</a>?
  </p>
</div>
```

---

## 22. Use Forgiving Input Formats

Accept variations; normalize behind the scenes.

```jsx
// Phone input that accepts any format
const formatPhone = (value) => {
  const digits = value.replace(/\D/g, '').slice(0, 10);
  if (digits.length >= 6) return `(${digits.slice(0,3)}) ${digits.slice(3,6)}-${digits.slice(6)}`;
  if (digits.length >= 3) return `(${digits.slice(0,3)}) ${digits.slice(3)}`;
  return digits;
};

<input type="tel" value={formatPhone(phone)} onChange={(e) => setPhone(e.target.value)}
  placeholder="(555) 123-4567"
  className="w-full px-3 py-2 border rounded-lg" />
```

---

## 23. Match Mobile Keyboards to Input Types

Reduces errors significantly with zero effort.

```jsx
<form className="space-y-4">
  {/* Email keyboard */}
  <input type="email" inputMode="email" autoComplete="email" />

  {/* Numeric keyboard for phone */}
  <input type="tel" inputMode="tel" autoComplete="tel" />

  {/* Number pad for verification codes */}
  <input type="text" inputMode="numeric" pattern="[0-9]*" autoComplete="one-time-code" maxLength={6}
    className="text-center text-2xl tracking-widest" />

  {/* Decimal keyboard for money */}
  <input type="text" inputMode="decimal" />

  {/* URL keyboard */}
  <input type="url" inputMode="url" autoComplete="url" />
</form>
```

---

## 24. Don't Use Placeholder as Label

Placeholders disappear on focus. Use persistent labels.

```jsx
// BAD: Placeholder only
<input placeholder="Email address" className="px-3 py-2 border rounded-lg" />

// GOOD: Floating label pattern
<div className="relative">
  <input id="email" type="email" placeholder=" " peer
    className="w-full px-3 pt-5 pb-2 border rounded-lg peer-placeholder-shown:pt-3" />
  <label htmlFor="email"
    className="absolute left-3 top-1 text-xs text-gray-500 transition-all
      peer-placeholder-shown:top-3 peer-placeholder-shown:text-base peer-focus:top-1 peer-focus:text-xs">
    Email address
  </label>
</div>

// BETTER: Simple label above
<div>
  <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
    Email address
  </label>
  <input id="email" type="email" placeholder="you@example.com"
    className="w-full px-3 py-2 border rounded-lg" />
</div>
```

---

## 25. Show Password Requirements Before Failure

Display rules as users type, not after they fail.

```jsx
const [password, setPassword] = useState('');
const checks = [
  { label: '8+ characters', valid: password.length >= 8 },
  { label: 'Uppercase letter', valid: /[A-Z]/.test(password) },
  { label: 'Number', valid: /\d/.test(password) },
];

<div className="space-y-2">
  <input type="password" value={password} onChange={(e) => setPassword(e.target.value)}
    className="w-full px-3 py-2 border rounded-lg" />
  <ul className="grid grid-cols-3 gap-2 text-xs">
    {checks.map(({ label, valid }) => (
      <li key={label} className={`flex items-center gap-1 ${valid ? 'text-green-600' : 'text-gray-400'}`}>
        {valid ? <CheckIcon className="w-3 h-3" /> : <CircleIcon className="w-3 h-3" />}
        {label}
      </li>
    ))}
  </ul>
</div>
```

---

## 26. Use Smart Defaults

Default to user's country, pre-fill from billing, remember preferences.

```jsx
// Shipping form with smart defaults
<form className="space-y-4">
  <select defaultValue={userCountry} className="w-full px-3 py-2 border rounded-lg">
    {countries.map(c => <option key={c.code} value={c.code}>{c.name}</option>)}
  </select>

  <label className="flex items-center gap-2">
    <input type="checkbox" defaultChecked onChange={(e) => {
      if (e.target.checked) copyBillingToShipping();
    }} className="rounded" />
    <span className="text-sm">Same as billing address</span>
  </label>
</form>
```

---

## 27. Design Single-Column Forms

Single-column outperforms multi-column. Labels above fields outperform labels beside.

```jsx
// BAD: Multi-column layout
<div className="grid grid-cols-2 gap-4">
  <Input label="First name" /><Input label="Last name" />
  <Input label="Email" /><Input label="Phone" />
</div>

// GOOD: Single column, logical groups
<form className="max-w-md space-y-6">
  <fieldset className="space-y-4">
    <legend className="text-lg font-medium">Personal Info</legend>
    <Input label="Full name" autoComplete="name" />
    <Input label="Email" type="email" autoComplete="email" />
  </fieldset>
  <fieldset className="space-y-4">
    <legend className="text-lg font-medium">Account</legend>
    <Input label="Password" type="password" />
  </fieldset>
</form>
```

---

## 28. Validate Required Fields Only on Submit

Flagging empty fields before user finishes is premature.

```jsx
const [submitted, setSubmitted] = useState(false);

const handleSubmit = (e) => {
  e.preventDefault();
  setSubmitted(true);
  if (isValid) submit();
};

<form onSubmit={handleSubmit}>
  <Input label="Name" required error={submitted && !name && 'Name is required'} />
  <Input label="Email" required error={submitted && !email && 'Email is required'} />
  <button type="submit">Submit</button>
</form>
```

---

# Feedback & System Status (29-36)

## 29. Provide Feedback Within 100ms

Longer latency feels like lag. Use immediate visual feedback.

```jsx
<button onClick={handleClick}
  className="px-4 py-2 bg-blue-600 text-white rounded-lg
    active:scale-95 active:bg-blue-700
    transition-transform duration-75">
  Save
</button>

// With loading state
<button disabled={loading}
  className={`px-4 py-2 rounded-lg transition-all
    ${loading ? 'bg-gray-400 cursor-wait' : 'bg-blue-600 hover:bg-blue-700 active:scale-95'}`}>
  {loading ? <Spinner className="w-5 h-5 animate-spin" /> : 'Save'}
</button>
```

---

## 30. Use Skeleton Screens Over Spinners

Skeletons show what's coming; spinners just show waiting.

```jsx
// Loading state with skeleton
<div className="space-y-4">
  {loading ? (
    <>
      <div className="h-6 w-1/3 bg-gray-200 rounded animate-pulse" />
      <div className="h-4 w-full bg-gray-200 rounded animate-pulse" />
      <div className="h-4 w-2/3 bg-gray-200 rounded animate-pulse" />
    </>
  ) : (
    <>
      <h2 className="text-xl font-semibold">{data.title}</h2>
      <p className="text-gray-600">{data.description}</p>
    </>
  )}
</div>

// Card skeleton component
const CardSkeleton = () => (
  <div className="p-4 border rounded-lg animate-pulse">
    <div className="h-32 bg-gray-200 rounded mb-4" />
    <div className="h-4 bg-gray-200 rounded w-3/4 mb-2" />
    <div className="h-4 bg-gray-200 rounded w-1/2" />
  </div>
);
```

---

## 31. Show Progress for Operations Over 4 Seconds

Under 1s: nothing. 1-4s: spinner. Over 4s: progress indicator.

```jsx
<div className="space-y-2">
  <div className="flex justify-between text-sm">
    <span>Uploading...</span>
    <span>{progress}%</span>
  </div>
  <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
    <div className="h-full bg-blue-600 transition-all duration-300" style={{ width: `${progress}%` }} />
  </div>
  {progress > 50 && <p className="text-xs text-gray-500">Almost there...</p>}
</div>

// Multi-step progress
<div className="flex items-center gap-2">
  {steps.map((step, i) => (
    <React.Fragment key={step}>
      <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm
        ${i < currentStep ? 'bg-green-500 text-white' : i === currentStep ? 'bg-blue-600 text-white' : 'bg-gray-200'}`}>
        {i < currentStep ? <CheckIcon className="w-4 h-4" /> : i + 1}
      </div>
      {i < steps.length - 1 && <div className={`flex-1 h-0.5 ${i < currentStep ? 'bg-green-500' : 'bg-gray-200'}`} />}
    </React.Fragment>
  ))}
</div>
```

---

## 32. Design Error Recovery, Not Just Messages

Provide recovery actions: retry, alternative paths, preserved data.

```jsx
<div className="p-4 bg-red-50 border border-red-200 rounded-lg">
  <div className="flex items-start gap-3">
    <ExclamationCircleIcon className="w-5 h-5 text-red-500 mt-0.5" />
    <div className="flex-1">
      <p className="font-medium text-red-800">Upload failed</p>
      <p className="text-sm text-red-600 mt-1">The file couldn't be uploaded due to a network error.</p>
      <div className="flex gap-2 mt-3">
        <button onClick={retry} className="px-3 py-1.5 text-sm bg-red-600 text-white rounded-lg">
          Try again
        </button>
        <button onClick={saveAsDraft} className="px-3 py-1.5 text-sm border border-red-300 rounded-lg text-red-700">
          Save as draft
        </button>
      </div>
    </div>
  </div>
</div>
```

---

## 33. Use Optimistic UI for High-Confidence Actions

Reflect expected changes immediately; revert only if they fail.

```jsx
const [liked, setLiked] = useState(false);

const handleLike = async () => {
  setLiked(!liked); // Optimistic update
  try {
    await api.toggleLike(postId);
  } catch {
    setLiked(liked); // Revert on failure
    toast.error('Failed to update');
  }
};

<button onClick={handleLike}
  className={`flex items-center gap-1 transition-colors ${liked ? 'text-red-500' : 'text-gray-500'}`}>
  <HeartIcon className={`w-5 h-5 ${liked ? 'fill-current' : ''}`} />
  <span>{likeCount + (liked ? 1 : 0)}</span>
</button>
```

---

## 34. Success Feedback Should Be Proportional

Don't over-celebrate minor actions. Match feedback to significance.

```jsx
// Minor action: subtle inline feedback
<button onClick={() => { copy(); setShowCopied(true); }}>
  {showCopied ? <span className="text-green-600">Copied!</span> : 'Copy'}
</button>

// Medium action: toast notification
toast.success('Settings saved');

// Major action: full confirmation
<div className="text-center py-12">
  <CheckCircleIcon className="w-16 h-16 text-green-500 mx-auto" />
  <h2 className="text-2xl font-bold mt-4">Payment successful!</h2>
  <p className="text-gray-600 mt-2">Your order #12345 is confirmed.</p>
  <button className="mt-6 px-6 py-2 bg-blue-600 text-white rounded-lg">View order</button>
</div>
```

---

## 35. Make System Status Visible

Users shouldn't wonder if their action worked.

```jsx
// Sync indicator
<div className="flex items-center gap-2 text-sm text-gray-500">
  {syncing ? (
    <><Spinner className="w-4 h-4 animate-spin" />Saving...</>
  ) : (
    <><CheckIcon className="w-4 h-4 text-green-500" />Saved</>
  )}
</div>

// Connection status
<div className={`flex items-center gap-2 text-sm px-3 py-1 rounded-full
  ${online ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
  <span className={`w-2 h-2 rounded-full ${online ? 'bg-green-500' : 'bg-red-500'}`} />
  {online ? 'Connected' : 'Offline'}
</div>
```

---

## 36. Empty States Should Guide Action

Empty screens are opportunities to onboard, not dead ends.

```jsx
<div className="text-center py-16 px-4">
  <FolderOpenIcon className="w-12 h-12 text-gray-300 mx-auto" />
  <h3 className="mt-4 text-lg font-medium text-gray-900">No projects yet</h3>
  <p className="mt-2 text-sm text-gray-500 max-w-sm mx-auto">
    Get started by creating your first project. It only takes a minute.
  </p>
  <button className="mt-6 px-4 py-2 bg-blue-600 text-white rounded-lg inline-flex items-center gap-2">
    <PlusIcon className="w-5 h-5" />Create project
  </button>
</div>
```

---

# Accessibility & Inclusive Design (37-44)

## 37. Maintain 4.5:1 Contrast Ratio Minimum

WCAG AA requires 4.5:1 for text, 3:1 for large text.

```jsx
// BAD: Low contrast
<p className="text-gray-400 bg-white">Hard to read</p>

// GOOD: Adequate contrast
<p className="text-gray-700 bg-white">Easy to read</p> {/* ~5:1 */}

// Check contrast programmatically
const contrastRatio = (l1, l2) => (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
```

---

## 38. Never Convey Information Through Color Alone

8% of men have color vision deficiency. Use icons, patterns, text as redundant cues.

```jsx
// BAD: Color only
<span className="text-red-500">Error</span>
<span className="text-green-500">Success</span>

// GOOD: Color + icon + text
<span className="flex items-center gap-1 text-red-600">
  <XCircleIcon className="w-4 h-4" />Failed
</span>
<span className="flex items-center gap-1 text-green-600">
  <CheckCircleIcon className="w-4 h-4" />Success
</span>

// Form validation with icon
<input className="border-red-500 pr-10" />
<ExclamationCircleIcon className="absolute right-3 top-1/2 -translate-y-1/2 w-5 h-5 text-red-500" />
```

---

## 39. Design for Keyboard-Only Navigation

Every interactive element needs visible focus states and logical tab order.

```jsx
// Custom focus ring
<button className="px-4 py-2 bg-blue-600 text-white rounded-lg
  focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
  Submit
</button>

// Skip link for keyboard users
<a href="#main-content"
   className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4
     focus:z-50 focus:px-4 focus:py-2 focus:bg-blue-600 focus:text-white focus:rounded">
  Skip to main content
</a>

// Focus trap for modals
<div role="dialog" aria-modal="true" onKeyDown={(e) => {
  if (e.key === 'Escape') onClose();
  if (e.key === 'Tab') trapFocus(e);
}}>
```

---

## 40. Provide Text Alternatives

Alt text for images, captions for video, transcripts for audio.

```jsx
// Decorative image (no alt needed)
<img src="pattern.svg" alt="" aria-hidden="true" />

// Meaningful image
<img src="chart.png" alt="Sales increased 25% from Q1 to Q2 2024" />

// Icon button with label
<button aria-label="Close dialog">
  <XIcon className="w-5 h-5" aria-hidden="true" />
</button>

// Video with captions
<video controls>
  <source src="demo.mp4" type="video/mp4" />
  <track kind="captions" src="captions.vtt" srcLang="en" label="English" default />
</video>
```

---

## 41. Use Semantic HTML

Semantics provide free accessibility and better SEO.

```jsx
// BAD: Div soup
<div className="header"><div onClick={nav}>Menu</div></div>
<div className="content"><div className="article">...</div></div>

// GOOD: Semantic elements
<header><nav><button>Menu</button></nav></header>
<main><article>...</article></main>

// Lists should be lists
<ul className="space-y-2">
  {items.map(item => <li key={item.id}>{item.name}</li>)}
</ul>
```

---

## 42. Announce Dynamic Content Changes

Screen readers need to know when content updates.

```jsx
// Live region for notifications
<div role="status" aria-live="polite" className="sr-only">
  {notification}
</div>

// Assertive for errors
<div role="alert" aria-live="assertive" className="p-4 bg-red-100 text-red-700 rounded">
  {error}
</div>

// Loading state announcement
<button aria-busy={loading} aria-describedby="loading-status">
  {loading ? 'Saving...' : 'Save'}
</button>
<span id="loading-status" className="sr-only">
  {loading ? 'Please wait, saving your changes' : ''}
</span>
```

---

## 43. Support Reduced Motion Preferences

Respect `prefers-reduced-motion` for users with vestibular disorders.

```jsx
// CSS approach
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}

// Tailwind config
module.exports = {
  theme: {
    extend: {
      animation: {
        'spin-slow': 'spin 3s linear infinite',
      }
    }
  }
}

// In JSX - check preference
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

<div className={prefersReducedMotion ? '' : 'animate-fadeIn'}>
  Content
</div>
```

---

## 44. Make Touch Targets Accessible

Ensure adequate size and spacing for users with motor impairments.

```jsx
// Checkbox with large touch target
<label className="flex items-center gap-3 p-3 -m-3 cursor-pointer">
  <input type="checkbox" className="w-5 h-5 rounded border-gray-300" />
  <span>Remember me</span>
</label>

// Link with adequate padding
<a href="/help" className="inline-block py-2 px-4 -mx-4 text-blue-600 hover:underline">
  Need help?
</a>
```

---

# Cognitive Load & Psychology (45-50)

## 45. Chunk Information Into Digestible Pieces

Break complex info into smaller, manageable chunks.

```jsx
// BAD: Wall of text
<p>{longDescription}</p>

// GOOD: Chunked with clear hierarchy
<div className="space-y-6">
  <section>
    <h3 className="font-medium mb-2">Features</h3>
    <ul className="space-y-2 text-gray-600">
      {features.map(f => <li key={f} className="flex items-start gap-2">
        <CheckIcon className="w-5 h-5 text-green-500 shrink-0" />{f}
      </li>)}
    </ul>
  </section>
  <section>
    <h3 className="font-medium mb-2">Requirements</h3>
    <ul className="space-y-2 text-gray-600">{requirements.map(r => <li key={r}>• {r}</li>)}</ul>
  </section>
</div>
```

---

## 46. Use Familiar Patterns

Users have mental models from other sites. Innovation belongs in your value prop, not navigation.

```jsx
// Standard e-commerce layout users expect
<header className="flex items-center justify-between p-4 border-b">
  <Logo />
  <SearchBar />
  <div className="flex items-center gap-4">
    <UserIcon /> {/* Expected position */}
    <CartIcon /> {/* Expected position */}
  </div>
</header>

// Standard form patterns
<form>
  <Input label="Email" /> {/* Label above */}
  <Input label="Password" type="password" />
  <div className="flex justify-between items-center">
    <Checkbox label="Remember me" />
    <a href="/forgot">Forgot password?</a> {/* Expected location */}
  </div>
  <button className="w-full">Sign in</button> {/* Full width CTA */}
</form>
```

---

## 47. Reduce Friction Where Possible

Every extra step loses users. Streamline critical paths.

```jsx
// BAD: Unnecessary steps
<button onClick={() => setShowConfirm(true)}>Add to cart</button>
{showConfirm && <Modal>Are you sure?<button>Yes</button></Modal>}

// GOOD: Immediate action with undo option
<button onClick={() => { addToCart(); toast(<>Added to cart <button onClick={undo}>Undo</button></>); }}>
  Add to cart
</button>

// Social login reduces friction
<div className="space-y-3">
  <button className="w-full py-2 border rounded-lg flex items-center justify-center gap-2">
    <GoogleIcon />Continue with Google
  </button>
  <div className="relative text-center">
    <span className="bg-white px-2 text-sm text-gray-500 relative z-10">or</span>
    <div className="absolute inset-0 flex items-center"><div className="w-full border-t" /></div>
  </div>
  <Input label="Email" />
</div>
```

---

## 48. Apply Micro-Commitments

Small first steps lead to completion. Start with low-friction actions.

```jsx
// Onboarding with micro-commitments
<div className="space-y-6">
  <h2>Let's personalize your experience</h2>

  {/* Step 1: Easy commitment */}
  <div>
    <p className="text-sm text-gray-600 mb-2">What brings you here?</p>
    <div className="flex flex-wrap gap-2">
      {goals.map(g => <Chip key={g} label={g} selectable />)}
    </div>
  </div>

  {/* Step 2: Slightly more */}
  {selectedGoal && (
    <div className="animate-fadeIn">
      <p className="text-sm text-gray-600 mb-2">How experienced are you?</p>
      <RadioGroup options={['Beginner', 'Intermediate', 'Expert']} />
    </div>
  )}
</div>
```

---

## 49. Leverage the Zeigarnik Effect

Incomplete tasks create psychological tension. Show progress.

```jsx
// Profile completion nudge
<div className="p-4 bg-blue-50 rounded-lg">
  <div className="flex items-center justify-between mb-2">
    <span className="text-sm font-medium">Profile 60% complete</span>
    <span className="text-sm text-blue-600">+20 points</span>
  </div>
  <div className="h-2 bg-blue-200 rounded-full">
    <div className="h-full bg-blue-600 rounded-full w-3/5" />
  </div>
  <button className="mt-3 text-sm text-blue-600 font-medium">
    Add profile photo to continue →
  </button>
</div>

// Course progress
<div className="flex items-center gap-3">
  <CircularProgress value={progress} />
  <div>
    <p className="font-medium">{course.title}</p>
    <p className="text-sm text-gray-500">{completedLessons}/{totalLessons} lessons</p>
  </div>
</div>
```

---

## 50. Apply the Serial Position Effect

Users remember first and last items best. Place critical items accordingly.

```jsx
// Navigation with important items at ends
<nav className="flex items-center gap-6">
  <a href="/dashboard" className="font-medium">Dashboard</a> {/* First = memorable */}
  <a href="/projects">Projects</a>
  <a href="/team">Team</a>
  <a href="/reports">Reports</a>
  <a href="/settings" className="font-medium">Settings</a> {/* Last = memorable */}
</nav>

// Feature list - best first, second-best last
<ul className="space-y-4">
  <li className="flex items-center gap-3">
    <StarIcon className="text-yellow-500" />Most important feature {/* First */}
  </li>
  <li className="flex items-center gap-3"><CheckIcon />Good feature</li>
  <li className="flex items-center gap-3"><CheckIcon />Another feature</li>
  <li className="flex items-center gap-3">
    <StarIcon className="text-yellow-500" />Second most important {/* Last */}
  </li>
</ul>
```

---

# Quick Reference

```jsx
// === VISUAL HIERARCHY ===
// Size > Color > Contrast > Proximity
<h1 className="text-3xl font-bold">Primary</h1>
<h2 className="text-xl font-semibold">Secondary</h2>
<p className="text-base text-gray-600">Body</p>

// === TOUCH TARGETS ===
// Minimum 44x44px, 8dp spacing
<button className="min-h-[44px] min-w-[44px] p-3">

// === FEEDBACK TIMING ===
// <100ms: immediate, 1-4s: spinner, >4s: progress
<button className="active:scale-95 transition-transform duration-75">

// === FORM VALIDATION ===
// Validate onBlur, not onChange
onBlur={() => validate()} // Good
onChange={() => validate()} // Bad

// === ERROR MESSAGES ===
// Human-readable, adjacent to field
<p className="mt-1 text-sm text-red-600">{error}</p>

// === ACCESSIBILITY ===
// Color + icon + text, 4.5:1 contrast
<span className="flex items-center gap-1 text-red-600">
  <XIcon aria-hidden />Error message
</span>

// === PROGRESSIVE DISCLOSURE ===
{showAdvanced && <AdvancedOptions />}
```

---

# UX Checklist

Before shipping any component:

- [ ] **Fitts' Law**: Primary CTAs large and close to interaction points?
- [ ] **Hick's Law**: Limited options (3-5) or progressive disclosure?
- [ ] **Touch Targets**: Minimum 44×44px with 8dp spacing?
- [ ] **Visual Hierarchy**: Clear size/color/contrast progression?
- [ ] **Feedback**: Immediate response (<100ms) for interactions?
- [ ] **Loading States**: Skeletons for content, progress for long ops?
- [ ] **Error Handling**: Human-readable, adjacent, actionable?
- [ ] **Form Validation**: After blur, not during typing?
- [ ] **Keyboard Navigation**: Focus visible, logical tab order?
- [ ] **Contrast Ratio**: 4.5:1 minimum for text?
- [ ] **Color Independence**: Info not conveyed by color alone?
- [ ] **Empty States**: Guides users toward action?
- [ ] **Current Location**: Navigation shows where user is?
- [ ] **Reduced Motion**: Respects prefers-reduced-motion?
