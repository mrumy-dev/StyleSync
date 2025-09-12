# UI Design System

## Design Principles

### Core Philosophy
StyleSync's design system is built on principles of simplicity, accessibility, and developer-focused usability. Every interface element serves a clear purpose and maintains consistency across all platforms.

### Fundamental Principles

#### 1. Clarity Over Cleverness
- **Clear Visual Hierarchy**: Information architecture guides user attention naturally
- **Purposeful Design**: Every element has a specific function and clear meaning
- **Immediate Understanding**: Users should understand functionality without explanation
- **Consistent Patterns**: Similar functions behave similarly across the application

#### 2. Developer-Centric Design
- **Workflow Integration**: Designs complement existing developer workflows
- **Keyboard-First Navigation**: All functions accessible via keyboard shortcuts
- **Context Preservation**: Maintain user context during style operations
- **Minimal Disruption**: Non-intrusive notifications and feedback

#### 3. Progressive Enhancement
- **Core Functionality First**: Essential features work without advanced UI
- **Graceful Degradation**: Reduced functionality rather than broken features
- **Adaptive Interfaces**: UI adapts to user expertise and preferences
- **Performance Conscious**: Fast loading and responsive interactions

#### 4. Accessibility First
- **Universal Design**: Usable by developers with diverse abilities
- **Screen Reader Support**: Complete ARIA implementation
- **Color Independence**: Information conveyed through multiple channels
- **Motor Accessibility**: Large touch targets and keyboard alternatives

## Animation Guidelines

### Animation Philosophy
Animations in StyleSync serve functional purposes: providing feedback, indicating state changes, and guiding attention. They should feel natural and enhance productivity rather than entertain.

### Core Animation Principles

#### 1. Purposeful Motion
- **Functional Animation**: Every animation serves a specific user need
- **Contextual Feedback**: Animations provide status and progress information
- **Spatial Awareness**: Motion indicates relationships between interface elements
- **State Communication**: Transitions clearly show state changes

#### 2. Performance Constraints
- **60 FPS Target**: Smooth animations at consistent frame rates
- **GPU Acceleration**: Hardware-accelerated animations when possible
- **Minimal Reflow**: Avoid animations that trigger layout recalculation
- **Reduced Motion**: Respect user preferences for reduced motion

#### 3. Timing and Easing
```css
/* Standard easing curves */
--ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
--ease-out: cubic-bezier(0, 0, 0.2, 1);
--ease-in: cubic-bezier(0.4, 0, 1, 1);
--ease-sharp: cubic-bezier(0.4, 0, 0.6, 1);

/* Standard durations */
--duration-instant: 100ms;
--duration-quick: 200ms;
--duration-normal: 300ms;
--duration-slow: 500ms;
```

#### 4. Animation Categories

**Micro-interactions** (100-200ms)
- Button hover states
- Form field focus
- Icon state changes
- Loading indicators

**Transitions** (200-300ms)
- Panel sliding
- Modal appearance
- Tab switching
- Content expansion

**Complex Sequences** (300-500ms)
- Multi-step processes
- Data visualization updates
- Onboarding flows
- Error state recovery

### Implementation Examples

#### Loading States
```css
.loading-spinner {
  animation: spin 1s linear infinite;
  opacity: 1;
  transition: opacity var(--duration-quick) var(--ease-out);
}

.loading-spinner.hidden {
  opacity: 0;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
```

#### State Transitions
```css
.button {
  background: var(--color-primary);
  transform: scale(1);
  transition: all var(--duration-quick) var(--ease-out);
}

.button:hover {
  background: var(--color-primary-hover);
  transform: scale(1.02);
}

.button:active {
  transform: scale(0.98);
  transition-duration: var(--duration-instant);
}
```

## Color System

### Color Philosophy
StyleSync uses a semantic color system that adapts to both light and dark themes while maintaining accessibility standards and supporting developer productivity in various lighting conditions.

### Primary Palette
```css
:root {
  /* Brand Colors */
  --color-primary: #6366f1;
  --color-primary-hover: #4f46e5;
  --color-primary-active: #4338ca;
  --color-primary-light: #a5b4fc;
  --color-primary-dark: #312e81;
  
  /* Secondary Colors */
  --color-secondary: #64748b;
  --color-secondary-hover: #475569;
  --color-secondary-active: #334155;
  --color-secondary-light: #cbd5e1;
  --color-secondary-dark: #1e293b;
}
```

### Semantic Colors
```css
:root {
  /* Status Colors */
  --color-success: #10b981;
  --color-success-light: #6ee7b7;
  --color-success-dark: #047857;
  
  --color-warning: #f59e0b;
  --color-warning-light: #fcd34d;
  --color-warning-dark: #b45309;
  
  --color-error: #ef4444;
  --color-error-light: #fca5a5;
  --color-error-dark: #b91c1c;
  
  --color-info: #3b82f6;
  --color-info-light: #93c5fd;
  --color-info-dark: #1d4ed8;
}
```

### Surface Colors
```css
:root {
  /* Light Theme */
  --color-background: #ffffff;
  --color-surface: #f8fafc;
  --color-surface-elevated: #ffffff;
  --color-border: #e2e8f0;
  --color-divider: #f1f5f9;
}

@media (prefers-color-scheme: dark) {
  :root {
    /* Dark Theme */
    --color-background: #0f172a;
    --color-surface: #1e293b;
    --color-surface-elevated: #334155;
    --color-border: #475569;
    --color-divider: #374151;
  }
}
```

### Text Colors
```css
:root {
  /* Light Theme Text */
  --color-text-primary: #0f172a;
  --color-text-secondary: #475569;
  --color-text-tertiary: #64748b;
  --color-text-inverse: #ffffff;
  --color-text-placeholder: #94a3b8;
}

@media (prefers-color-scheme: dark) {
  :root {
    /* Dark Theme Text */
    --color-text-primary: #f1f5f9;
    --color-text-secondary: #cbd5e1;
    --color-text-tertiary: #94a3b8;
    --color-text-inverse: #0f172a;
    --color-text-placeholder: #64748b;
  }
}
```

### Accessibility Standards
- **WCAG 2.1 AA**: Minimum 4.5:1 contrast ratio for normal text
- **WCAG 2.1 AAA**: 7:1 contrast ratio for important text
- **Color Blindness**: Information never conveyed through color alone
- **High Contrast**: Support for high contrast operating system modes

## Typography Scale

### Font Families
```css
:root {
  /* Primary font stack for UI */
  --font-family-primary: 'Inter', -apple-system, BlinkMacSystemFont, 
                         'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  
  /* Monospace font for code */
  --font-family-mono: 'JetBrains Mono', 'SF Mono', Monaco, 'Cascadia Code',
                       'Roboto Mono', Consolas, 'Courier New', monospace;
  
  /* Alternative font for headings */
  --font-family-heading: 'Inter', -apple-system, BlinkMacSystemFont,
                         'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
}
```

### Type Scale
```css
:root {
  /* Font sizes following a modular scale */
  --font-size-xs: 0.75rem;    /* 12px */
  --font-size-sm: 0.875rem;   /* 14px */
  --font-size-base: 1rem;     /* 16px */
  --font-size-lg: 1.125rem;   /* 18px */
  --font-size-xl: 1.25rem;    /* 20px */
  --font-size-2xl: 1.5rem;    /* 24px */
  --font-size-3xl: 1.875rem;  /* 30px */
  --font-size-4xl: 2.25rem;   /* 36px */
  --font-size-5xl: 3rem;      /* 48px */
}
```

### Line Heights
```css
:root {
  /* Relative line heights */
  --line-height-none: 1;
  --line-height-tight: 1.25;
  --line-height-snug: 1.375;
  --line-height-normal: 1.5;
  --line-height-relaxed: 1.625;
  --line-height-loose: 2;
}
```

### Font Weights
```css
:root {
  --font-weight-thin: 100;
  --font-weight-light: 300;
  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;
  --font-weight-extrabold: 800;
  --font-weight-black: 900;
}
```

### Typography Classes
```css
/* Heading styles */
.heading-1 {
  font-family: var(--font-family-heading);
  font-size: var(--font-size-4xl);
  font-weight: var(--font-weight-bold);
  line-height: var(--line-height-tight);
  letter-spacing: -0.025em;
}

.heading-2 {
  font-family: var(--font-family-heading);
  font-size: var(--font-size-3xl);
  font-weight: var(--font-weight-semibold);
  line-height: var(--line-height-tight);
  letter-spacing: -0.025em;
}

/* Body text styles */
.body-large {
  font-family: var(--font-family-primary);
  font-size: var(--font-size-lg);
  font-weight: var(--font-weight-normal);
  line-height: var(--line-height-relaxed);
}

.body-normal {
  font-family: var(--font-family-primary);
  font-size: var(--font-size-base);
  font-weight: var(--font-weight-normal);
  line-height: var(--line-height-normal);
}

/* Code styles */
.code-inline {
  font-family: var(--font-family-mono);
  font-size: 0.875em;
  background: var(--color-surface);
  padding: 0.125rem 0.25rem;
  border-radius: 0.25rem;
}

.code-block {
  font-family: var(--font-family-mono);
  font-size: var(--font-size-sm);
  line-height: var(--line-height-relaxed);
  background: var(--color-surface);
  padding: 1rem;
  border-radius: 0.5rem;
  overflow-x: auto;
}
```

## Component Library

### Design Tokens
All components use standardized design tokens for consistency and maintainability.

```css
:root {
  /* Spacing scale */
  --spacing-0: 0;
  --spacing-1: 0.25rem;   /* 4px */
  --spacing-2: 0.5rem;    /* 8px */
  --spacing-3: 0.75rem;   /* 12px */
  --spacing-4: 1rem;      /* 16px */
  --spacing-5: 1.25rem;   /* 20px */
  --spacing-6: 1.5rem;    /* 24px */
  --spacing-8: 2rem;      /* 32px */
  --spacing-10: 2.5rem;   /* 40px */
  --spacing-12: 3rem;     /* 48px */
  
  /* Border radius */
  --radius-none: 0;
  --radius-sm: 0.125rem;   /* 2px */
  --radius-base: 0.25rem;  /* 4px */
  --radius-md: 0.375rem;   /* 6px */
  --radius-lg: 0.5rem;     /* 8px */
  --radius-xl: 0.75rem;    /* 12px */
  --radius-full: 9999px;
  
  /* Shadows */
  --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  --shadow-base: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
  --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
  --shadow-xl: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
}
```

### Button Components
```css
.button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--spacing-2);
  padding: var(--spacing-3) var(--spacing-4);
  font-family: var(--font-family-primary);
  font-size: var(--font-size-sm);
  font-weight: var(--font-weight-medium);
  line-height: 1;
  border: 1px solid transparent;
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--duration-quick) var(--ease-out);
  text-decoration: none;
  white-space: nowrap;
}

.button:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}

.button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Button variants */
.button--primary {
  background: var(--color-primary);
  color: var(--color-text-inverse);
}

.button--primary:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.button--secondary {
  background: var(--color-surface);
  color: var(--color-text-primary);
  border-color: var(--color-border);
}

.button--secondary:hover:not(:disabled) {
  background: var(--color-surface-elevated);
  border-color: var(--color-primary);
}

/* Button sizes */
.button--sm {
  padding: var(--spacing-2) var(--spacing-3);
  font-size: var(--font-size-xs);
}

.button--lg {
  padding: var(--spacing-4) var(--spacing-6);
  font-size: var(--font-size-base);
}
```

### Form Components
```css
.input {
  display: block;
  width: 100%;
  padding: var(--spacing-3);
  font-family: var(--font-family-primary);
  font-size: var(--font-size-sm);
  color: var(--color-text-primary);
  background: var(--color-background);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  transition: all var(--duration-quick) var(--ease-out);
}

.input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
}

.input::placeholder {
  color: var(--color-text-placeholder);
}

.input:invalid {
  border-color: var(--color-error);
}

.input:invalid:focus {
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1);
}

.label {
  display: block;
  font-size: var(--font-size-sm);
  font-weight: var(--font-weight-medium);
  color: var(--color-text-primary);
  margin-bottom: var(--spacing-2);
}

.field-error {
  display: block;
  font-size: var(--font-size-xs);
  color: var(--color-error);
  margin-top: var(--spacing-1);
}
```

### Layout Components
```css
.container {
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 var(--spacing-4);
}

.stack {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-4);
}

.stack--tight {
  gap: var(--spacing-2);
}

.stack--loose {
  gap: var(--spacing-8);
}

.cluster {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-3);
  align-items: center;
}

.grid {
  display: grid;
  gap: var(--spacing-4);
}

.grid--2col {
  grid-template-columns: repeat(2, 1fr);
}

.grid--3col {
  grid-template-columns: repeat(3, 1fr);
}

@media (max-width: 768px) {
  .grid--2col,
  .grid--3col {
    grid-template-columns: 1fr;
  }
}
```

### Status and Feedback Components
```css
.alert {
  padding: var(--spacing-4);
  border-radius: var(--radius-md);
  border-left: 4px solid;
  background: var(--color-surface);
}

.alert--success {
  border-color: var(--color-success);
  background: var(--color-success-light);
  color: var(--color-success-dark);
}

.alert--warning {
  border-color: var(--color-warning);
  background: var(--color-warning-light);
  color: var(--color-warning-dark);
}

.alert--error {
  border-color: var(--color-error);
  background: var(--color-error-light);
  color: var(--color-error-dark);
}

.badge {
  display: inline-flex;
  align-items: center;
  padding: var(--spacing-1) var(--spacing-2);
  font-size: var(--font-size-xs);
  font-weight: var(--font-weight-medium);
  border-radius: var(--radius-full);
  background: var(--color-surface);
  color: var(--color-text-secondary);
  border: 1px solid var(--color-border);
}

.badge--success {
  background: var(--color-success-light);
  color: var(--color-success-dark);
  border-color: var(--color-success);
}
```

## Responsive Design

### Breakpoint System
```css
:root {
  --breakpoint-sm: 640px;
  --breakpoint-md: 768px;
  --breakpoint-lg: 1024px;
  --breakpoint-xl: 1280px;
  --breakpoint-2xl: 1536px;
}

/* Mobile first media queries */
@media (min-width: 640px) { /* sm */ }
@media (min-width: 768px) { /* md */ }
@media (min-width: 1024px) { /* lg */ }
@media (min-width: 1280px) { /* xl */ }
@media (min-width: 1536px) { /* 2xl */ }
```

### Responsive Utilities
```css
/* Container queries for component-level responsiveness */
@container (max-width: 400px) {
  .responsive-component {
    flex-direction: column;
  }
}

/* Responsive typography */
@media (max-width: 768px) {
  .heading-1 {
    font-size: var(--font-size-3xl);
  }
  
  .heading-2 {
    font-size: var(--font-size-2xl);
  }
}

/* Responsive spacing */
@media (max-width: 768px) {
  .container {
    padding: 0 var(--spacing-3);
  }
  
  .stack {
    gap: var(--spacing-3);
  }
}
```

This design system provides a comprehensive foundation for building consistent, accessible, and maintainable user interfaces across the StyleSync platform. All components follow these principles and can be composed together to create complex interfaces while maintaining design coherence.