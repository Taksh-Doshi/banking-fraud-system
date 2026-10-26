import { useMemo, useState, type ReactNode, type SVGProps } from 'react'

type Screen =
  | 'landing'
  | 'login'
  | 'dashboard'
  | 'transactions'
  | 'fraud'
  | 'investigation'
  | 'audit'
  | 'settings'
  | 'error'

type Theme = 'dark' | 'light'
type IconName =
  | 'grid'
  | 'wallet'
  | 'swap'
  | 'card'
  | 'help'
  | 'settings'
  | 'shield'
  | 'users'
  | 'search'
  | 'bell'
  | 'sun'
  | 'moon'
  | 'arrowUp'
  | 'arrowDown'
  | 'chevron'
  | 'plus'
  | 'download'
  | 'filter'
  | 'file'
  | 'lock'
  | 'eye'
  | 'check'
  | 'alert'
  | 'menu'
  | 'close'
  | 'logout'
  | 'bank'
  | 'clock'
  | 'chart'
  | 'activity'
  | 'user'

const paths: Record<IconName, ReactNode> = {
  grid: <><rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/></>,
  wallet: <><path d="M4 7.5A2.5 2.5 0 0 1 6.5 5H19a2 2 0 0 1 2 2v12H6a2 2 0 0 1-2-2V7.5Z"/><path d="M4.5 8.5h13M16 12h5v4h-5a2 2 0 0 1 0-4Z"/></>,
  swap: <><path d="m7 7 3-3 3 3M10 4v13M17 17l-3 3-3-3M14 20V7"/></>,
  card: <><rect x="3" y="5" width="18" height="14" rx="3"/><path d="M3 10h18M7 15h4"/></>,
  help: <><circle cx="12" cy="12" r="9"/><path d="M9.8 9a2.4 2.4 0 1 1 3.7 2c-1 .7-1.5 1.1-1.5 2.5M12 17.5h.01"/></>,
  settings: <><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1a1.7 1.7 0 0 0 1.9.3A1.7 1.7 0 0 0 10 3v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z"/></>,
  shield: <><path d="M12 2.8 20 6v5.5c0 5-3.4 8.5-8 10-4.6-1.5-8-5-8-10V6l8-3.2Z"/><path d="m8.5 12 2.2 2.2 4.8-5"/></>,
  users: <><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></>,
  search: <><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></>,
  bell: <><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/></>,
  sun: <><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></>,
  moon: <path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8Z"/>,
  arrowUp: <><path d="m18 15-6-6-6 6"/><path d="M12 9v12"/></>,
  arrowDown: <><path d="m6 9 6 6 6-6"/><path d="M12 3v12"/></>,
  chevron: <path d="m9 18 6-6-6-6"/>,
  plus: <path d="M12 5v14M5 12h14"/>,
  download: <><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></>,
  filter: <path d="M4 5h16M7 12h10M10 19h4"/>,
  file: <><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6M8 13h8M8 17h6"/></>,
  lock: <><rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></>,
  eye: <><path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6Z"/><circle cx="12" cy="12" r="2.5"/></>,
  check: <path d="m5 12 4 4L19 6"/>,
  alert: <><path d="M10.3 3.7 2.5 17a2 2 0 0 0 1.7 3h15.6a2 2 0 0 0 1.7-3L13.7 3.7a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/></>,
  menu: <path d="M4 7h16M4 12h16M4 17h16"/>,
  close: <path d="m6 6 12 12M18 6 6 18"/>,
  logout: <><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></>,
  bank: <><path d="m3 9 9-5 9 5M5 10h14M6 10v7M10 10v7M14 10v7M18 10v7M4 18h16M3 21h18"/></>,
  clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
  chart: <><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></>,
  activity: <path d="M3 12h4l2-7 4 14 2-7h6"/>,
  user: <><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></>,
}

function Icon({ name, size = 18, ...props }: { name: IconName; size?: number } & SVGProps<SVGSVGElement>) {
  return <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...props}>{paths[name]}</svg>
}

function Logo({ compact = false }: { compact?: boolean }) {
  return <div className="logo" aria-label="SecureBank">
    <svg className="logo-mark" viewBox="0 0 42 48" aria-hidden="true">
      <path d="M21 1.5 39.5 9v13c0 11.7-7.9 20.1-18.5 24.5C10.4 42.1 2.5 33.7 2.5 22V9L21 1.5Z" fill="currentColor"/>
      <path d="m10.5 18.1 10.5-6 10.5 6M13 20h16M14.5 20v10M19 20v10M23 20v10M27.5 20v10M12.5 32h17" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
    {!compact && <div className="logo-copy"><strong><span>Secure</span><b>Bank</b></strong><small>Safer Transactions. Stronger Tomorrow.</small></div>}
  </div>
}

function Text({ as: Tag = 'div', className = '', children }: { as?: keyof JSX.IntrinsicElements; className?: string; children: ReactNode }) {
  return <Tag className={className}>{children}</Tag>
}

function Button({ children, variant = 'primary', icon, onClick, type = 'button', className = '', disabled = false }: { children: ReactNode; variant?: 'primary' | 'secondary' | 'ghost' | 'danger'; icon?: IconName; onClick?: () => void; type?: 'button' | 'submit'; className?: string; disabled?: boolean }) {
  return <button type={type} className={`btn btn-${variant} ${className}`} onClick={onClick} disabled={disabled}>{icon && <Icon name={icon}/>}<span>{children}</span></button>
}

function Card({ children, className = '', onClick }: { children: ReactNode; className?: string; onClick?: () => void }) {
  return <section className={`card ${className}`} onClick={onClick}>{children}</section>
}

function Badge({ children, tone = 'neutral' }: { children: ReactNode; tone?: 'success' | 'warning' | 'danger' | 'info' | 'neutral' | 'critical' }) {
  return <span className={`badge badge-${tone}`}>{children}</span>
}

function Field({ label, placeholder, type = 'text', icon, helper, defaultValue }: { label: string; placeholder?: string; type?: string; icon?: IconName; helper?: string; defaultValue?: string }) {
  return <label className="field"><span>{label}</span><div className="input-wrap">{icon && <Icon name={icon}/>}<input type={type} placeholder={placeholder} defaultValue={defaultValue}/>{type === 'password' && <Icon name="eye"/>}</div>{helper && <small>{helper}</small>}</label>
}

function SelectField({ label, children }: { label: string; children: ReactNode }) {
  return <label className="field"><span>{label}</span><div className="select-wrap"><select>{children}</select><Icon name="chevron"/></div></label>
}

const customerNav: { label: string; icon: IconName; screen: Screen }[] = [
  { label: 'Dashboard', icon: 'grid', screen: 'dashboard' },
  { label: 'Accounts', icon: 'wallet', screen: 'dashboard' },
  { label: 'Transactions', icon: 'swap', screen: 'transactions' },
  { label: 'Cards', icon: 'card', screen: 'dashboard' },
  { label: 'Support', icon: 'help', screen: 'error' },
  { label: 'Settings', icon: 'settings', screen: 'settings' },
]

const staffNav: { label: string; icon: IconName; screen: Screen }[] = [
  { label: 'Dashboard', icon: 'grid', screen: 'fraud' },
  { label: 'Fraud Monitoring', icon: 'shield', screen: 'fraud' },
  { label: 'Transactions', icon: 'swap', screen: 'transactions' },
  { label: 'Customers', icon: 'users', screen: 'fraud' },
  { label: 'Investigations', icon: 'search', screen: 'investigation' },
  { label: 'Audit Logs', icon: 'file', screen: 'audit' },
  { label: 'Reports', icon: 'chart', screen: 'audit' },
]

function Topbar({ title, subtitle, theme, setTheme, openMenu }: { title: string; subtitle?: string; theme: Theme; setTheme: (t: Theme) => void; openMenu: () => void }) {
  return <header className="topbar">
    <button className="icon-btn mobile-menu" onClick={openMenu} aria-label="Open menu"><Icon name="menu"/></button>
    <div className="topbar-title"><Text as="h1">{title}</Text>{subtitle && <Text as="p">{subtitle}</Text>}</div>
    <div className="topbar-actions">
      <button className="icon-btn theme-btn" onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')} aria-label="Change theme"><Icon name={theme === 'dark' ? 'sun' : 'moon'}/></button>
      <button className="icon-btn notification" aria-label="Notifications"><Icon name="bell"/><i/></button>
      <div className="profile"><div className="avatar">AJ</div><div><strong>Alex Johnson</strong><span>Customer</span></div><Icon name="chevron" size={14}/></div>
    </div>
  </header>
}

function Sidebar({ screen, onNavigate, staff = false, open, close }: { screen: Screen; onNavigate: (s: Screen) => void; staff?: boolean; open: boolean; close: () => void }) {
  const nav = staff ? staffNav : customerNav
  return <><aside className={`sidebar ${open ? 'is-open' : ''}`}>
    <div className="side-logo"><Logo/></div>
    <button className="icon-btn side-close" onClick={close}><Icon name="close"/></button>
    <div className="side-label">{staff ? 'OPERATIONS' : 'PERSONAL BANKING'}</div>
    <nav>{nav.map((item) => <button key={item.label} className={`nav-item ${screen === item.screen ? 'active' : ''}`} onClick={() => { onNavigate(item.screen); close() }}><Icon name={item.icon}/><span>{item.label}</span>{item.label === 'Fraud Monitoring' && <em>12</em>}</button>)}</nav>
    <div className="side-spacer"/>
    {staff && <div className="security-box"><Icon name="shield"/><div><strong>Systems secure</strong><span>All services operational</span></div></div>}
    <button className="nav-item logout" onClick={() => onNavigate('landing')}><Icon name="logout"/><span>Sign out</span></button>
    <div className="side-user"><div className="avatar">{staff ? 'MK' : 'AJ'}</div><div><strong>{staff ? 'Maya Kapoor' : 'Alex Johnson'}</strong><span>{staff ? 'Fraud Analyst' : '•••• 4821'}</span></div><Icon name="chevron"/></div>
  </aside>{open && <button className="scrim" onClick={close} aria-label="Close menu"/>}</>
}

function AppShell({ children, screen, onNavigate, theme, setTheme, staff = false, title, subtitle }: { children: ReactNode; screen: Screen; onNavigate: (s: Screen) => void; theme: Theme; setTheme: (t: Theme) => void; staff?: boolean; title: string; subtitle?: string }) {
  const [menu, setMenu] = useState(false)
  return <div className={`app-shell ${staff ? 'staff-shell' : ''}`}><Sidebar screen={screen} onNavigate={onNavigate} staff={staff} open={menu} close={() => setMenu(false)}/><main className="main"><Topbar title={title} subtitle={subtitle} theme={theme} setTheme={setTheme} openMenu={() => setMenu(true)}/>{children}</main></div>
}

function MiniChart({ danger = false }: { danger?: boolean }) {
  return <svg className={`mini-chart ${danger ? 'danger-chart' : ''}`} viewBox="0 0 320 90" preserveAspectRatio="none" aria-label="Trend chart">
    <defs><linearGradient id={danger ? 'redFade' : 'blueFade'} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="currentColor" stopOpacity=".28"/><stop offset="1" stopColor="currentColor" stopOpacity="0"/></linearGradient></defs>
    <path className="chart-grid" d="M0 18h320M0 45h320M0 72h320"/>
    <path className="chart-area" d="M0 69 28 62 55 66 82 48 110 53 138 32 166 42 194 24 222 31 250 13 280 22 320 8V90H0Z" fill={`url(#${danger ? 'redFade' : 'blueFade'})`}/>
    <path className="chart-line" d="M0 69 28 62 55 66 82 48 110 53 138 32 166 42 194 24 222 31 250 13 280 22 320 8"/>
  </svg>
}

const transactions = [
  { icon: 'bank' as IconName, title: 'Salary Credit', sub: 'Today, 09:42 AM', amount: '+ ₹85,000.00', status: 'Completed', tone: 'success' as const },
  { icon: 'card' as IconName, title: 'Urban Market', sub: 'Today, 08:15 AM', amount: '− ₹2,480.00', status: 'Completed', tone: 'success' as const },
  { icon: 'swap' as IconName, title: 'Transfer to Priya S.', sub: 'Yesterday, 05:30 PM', amount: '− ₹12,000.00', status: 'Pending', tone: 'warning' as const },
  { icon: 'wallet' as IconName, title: 'ATM Withdrawal', sub: '12 Jun, 02:10 PM', amount: '− ₹5,000.00', status: 'Completed', tone: 'success' as const },
  { icon: 'alert' as IconName, title: 'StreamPro Subscription', sub: '11 Jun, 10:25 AM', amount: '− ₹799.00', status: 'Failed', tone: 'danger' as const },
]

function TransactionRows({ compact = false }: { compact?: boolean }) {
  return <div className="transaction-list">{transactions.slice(0, compact ? 4 : 5).map((t) => <div className="transaction-row" key={t.title}><div className="transaction-icon"><Icon name={t.icon}/></div><div className="transaction-name"><strong>{t.title}</strong><span>{t.sub}</span></div><div className="transaction-amount"><strong className={t.amount.startsWith('+') ? 'positive' : ''}>{t.amount}</strong><Badge tone={t.tone}>{t.status}</Badge></div></div>)}</div>
}

function Landing({ go }: { go: (s: Screen) => void }) {
  return <div className="landing">
    <header className="landing-nav"><Logo/><nav><button>Home</button><button>Features</button><button>Security</button><button>About</button></nav><Button onClick={() => go('login')}>Get Started</Button></header>
    <main>
      <section className="hero">
        <div className="hero-glow"/>
        <div className="hero-content">
          <Badge tone="info"><Icon name="shield" size={14}/> Secure by design</Badge>
          <Text as="h1">Your Money.<br/><span>Our Priority.</span></Text>
          <Text as="p">Experience banking that is effortless, transparent, and protected at every step. Monitor every transaction with confidence.</Text>
          <div className="hero-actions"><Button onClick={() => go('login')}>Get Started <Icon name="chevron"/></Button><Button variant="secondary">Learn More</Button></div>
          <div className="trust-row"><div className="avatar-stack"><i>AJ</i><i>MK</i><i>PS</i></div><div><strong>Trusted by 2M+ customers</strong><span>Rated 4.9 out of 5</span></div></div>
        </div>
        <div className="hero-visual">
          <div className="visual-orbit orbit-one"/><div className="visual-orbit orbit-two"/>
          <div className="secure-card"><div className="card-top"><Logo compact/><span>PLATINUM</span></div><div className="chip"/><strong>4821&nbsp;&nbsp; 7634&nbsp;&nbsp; 9012&nbsp;&nbsp; 4582</strong><div className="card-foot"><div><span>CARD HOLDER</span><b>ALEX JOHNSON</b></div><div><span>VALID THRU</span><b>09/29</b></div></div></div>
          <div className="floating-panel panel-balance"><span>Total Balance</span><strong>₹12,48,000</strong><em><Icon name="arrowUp"/> 8.4%</em></div>
          <div className="floating-panel panel-safe"><i><Icon name="shield"/></i><div><strong>Payment secured</strong><span>Protected by SecureShield</span></div></div>
          <div className="landing-dashboard"><div className="mock-side"><Logo compact/>{[1,2,3,4].map(i=><i key={i}/>)}</div><div className="mock-main"><div className="mock-head"/><div className="mock-grid"><div/><div/><div/></div><MiniChart/></div></div>
        </div>
      </section>
      <section className="features"><div className="section-heading"><span>BUILT FOR PEACE OF MIND</span><Text as="h2">Everything you need to bank securely</Text><Text as="p">Powerful protection meets beautifully simple banking.</Text></div><div className="feature-grid">
        {[
          ['shield','Secure Transactions','Industry-grade protection watches over every payment, transfer, and account change.'],
          ['activity','Fraud Protection','Real-time monitoring detects unusual activity before it becomes a problem.'],
          ['help','24/7 Support','Expert help is always available when you need guidance or reassurance.'],
          ['users','Trusted by Millions','Built on clarity and trust for customers and teams across the country.'],
        ].map(([icon,title,copy])=><Card key={title}><div className="feature-icon"><Icon name={icon as IconName}/></div><Text as="h3">{title}</Text><Text as="p">{copy}</Text><button>Learn more <Icon name="chevron"/></button></Card>)}
      </div></section>
    </main>
    <footer><Logo/><Text as="p">Modern banking, thoughtfully secured.</Text><div><button>Privacy</button><button>Terms</button><button>Contact</button></div><span>© 2025 SecureBank. Demonstration interface.</span></footer>
  </div>
}

function Login({ go }: { go: (s: Screen) => void }) {
  const [role, setRole] = useState<'customer'|'staff'>('customer')
  const [loading, setLoading] = useState(false)
  const submit = () => { setLoading(true); setTimeout(() => go(role === 'customer' ? 'dashboard' : 'fraud'), 650) }
  return <div className="login-page">
    <div className="login-form-side"><button className="back-link" onClick={() => go('landing')}>← Back to home</button><div className="login-box"><Logo/><div className="login-heading"><Text as="h1">Welcome back</Text><Text as="p">Sign in to continue to your secure banking portal.</Text></div>
      <div className="role-switch"><button className={role==='customer'?'active':''} onClick={()=>setRole('customer')}><Icon name="user"/>Customer</button><button className={role==='staff'?'active':''} onClick={()=>setRole('staff')}><Icon name="shield"/>Staff</button></div>
      <form onSubmit={(e)=>{e.preventDefault();submit()}}><Field label="Email or username" placeholder="alex.johnson@example.com" icon="user"/><Field label="Password" placeholder="Enter your password" type="password" icon="lock"/>
        <div className="form-meta"><label><input type="checkbox" defaultChecked/> <span>Remember me</span></label><button type="button">Forgot password?</button></div>
        <Button type="submit" className="full-btn" disabled={loading}>{loading ? <><span className="spinner"/>Authenticating…</> : <>Sign in securely <Icon name="chevron"/></>}</Button>
      </form><Text as="p" className="support-copy">Having trouble signing in? <button>Contact support</button></Text><div className="security-note"><Icon name="lock"/><span>Your connection is encrypted and protected.</span></div>
    </div></div>
    <div className="login-art"><div className="art-grid"/><Logo compact/><div className="art-copy"><div className="art-shield"><Icon name="shield" size={42}/></div><Text as="h2">Security that never sleeps.</Text><Text as="p">Intelligent monitoring protects every transaction, around the clock.</Text><div className="art-stat"><strong>99.99%</strong><span>platform uptime</span></div><div className="art-stat"><strong>24/7</strong><span>fraud monitoring</span></div></div><Text as="small">SecureBank Security Operations • Live</Text></div>
  </div>
}

function Dashboard({ screen, go, theme, setTheme }: { screen: Screen; go: (s: Screen)=>void; theme: Theme; setTheme:(t:Theme)=>void }) {
  return <AppShell screen={screen} onNavigate={go} theme={theme} setTheme={setTheme} title="Good morning, Alex" subtitle="Here’s what’s happening with your money today.">
    <div className="page-content dashboard-content">
      <section className="balance-layout"><Card className="balance-card"><div className="balance-head"><div><span>Available balance</span><strong>₹12,480.00</strong><small>Savings Account •••• 4821</small></div><button><Icon name="eye"/></button></div><div className="balance-chart"><div className="chart-label"><span>Balance trend</span><Badge tone="success"><Icon name="arrowUp"/> 8.4% this month</Badge></div><MiniChart/><div className="axis"><span>May 15</span><span>May 22</span><span>May 29</span><span>Jun 05</span><span>Jun 12</span></div></div></Card>
      <Card className="account-card"><div className="card-heading"><div><span>PRIMARY ACCOUNT</span><Text as="h3">Savings account</Text></div><Badge tone="success">Active</Badge></div><div className="account-number"><span>Account number</span><strong>•••• •••• 4821</strong></div><div className="account-meta"><div><span>Account type</span><strong>Premium Savings</strong></div><div><span>Interest rate</span><strong>4.25% p.a.</strong></div></div><button>View account details <Icon name="chevron"/></button></Card></section>
      <section><div className="section-bar"><div><Text as="h2">Quick actions</Text><Text as="p">Move and manage your money</Text></div></div><div className="quick-grid">{[
        ['plus','Cash Deposit','Add money to your account'],
        ['swap','Transfer','Send money instantly'],
        ['arrowDown','Cash Withdrawal','Plan a withdrawal'],
        ['file','Pay Bills','Settle bills and utilities'],
      ].map(([icon,title,sub])=><button className="quick-action" key={title} onClick={()=>go('transactions')}><i><Icon name={icon as IconName}/></i><div><strong>{title}</strong><span>{sub}</span></div><Icon name="chevron"/></button>)}</div></section>
      <section className="dashboard-bottom"><Card><div className="card-title-row"><div><Text as="h2">Recent transactions</Text><Text as="p">Your latest account activity</Text></div><button onClick={()=>go('transactions')}>View all <Icon name="chevron"/></button></div><TransactionRows compact/></Card><Card className="spend-card"><div className="card-title-row"><div><Text as="h2">Monthly spend</Text><Text as="p">June 2025</Text></div><button><Icon name="filter"/></button></div><div className="donut"><div><strong>₹38,240</strong><span>Total spent</span></div></div><div className="legend"><span><i className="l-blue"/>Shopping <b>36%</b></span><span><i className="l-cyan"/>Bills <b>28%</b></span><span><i className="l-purple"/>Food <b>22%</b></span><span><i className="l-muted"/>Other <b>14%</b></span></div></Card></section>
    </div>
  </AppShell>
}

function Transactions({ screen, go, theme, setTheme }: { screen: Screen; go:(s:Screen)=>void; theme:Theme; setTheme:(t:Theme)=>void }) {
  const [tab,setTab]=useState('Transfer')
  const [confirm,setConfirm]=useState(false)
  const [success,setSuccess]=useState(false)
  return <AppShell screen={screen} onNavigate={go} theme={theme} setTheme={setTheme} title="Transactions" subtitle="Move money securely and review your activity."><div className="page-content">
    <div className="workspace-grid"><Card className="form-card"><div className="card-title-row"><div><Text as="h2">New transaction</Text><Text as="p">Choose an action and enter the details below.</Text></div><div className="secure-label"><Icon name="lock"/> Secure</div></div>
      <div className="tabs">{['Deposit','Withdrawal','Transfer'].map(t=><button className={tab===t?'active':''} onClick={()=>setTab(t)} key={t}>{t}</button>)}</div>
      {success ? <div className="success-state"><i><Icon name="check" size={30}/></i><Text as="h2">Transaction scheduled</Text><Text as="p">Your {tab.toLowerCase()} request has been received. Reference: SBX-820491</Text><Button onClick={()=>setSuccess(false)}>Make another transaction</Button></div> : <div className="transaction-form"><SelectField label="From account"><option>Premium Savings •••• 4821 — ₹12,480.00</option><option>Current Account •••• 2840 — ₹84,220.00</option></SelectField>{tab==='Transfer'&&<Field label="Recipient or destination account" placeholder="Enter account number or UPI ID" icon="user"/>}<Field label="Amount" placeholder="₹ 0.00" helper="Daily transfer limit: ₹2,00,000"/><Field label="Reference or note (optional)" placeholder="What is this transaction for?" icon="file"/><div className="info-callout"><Icon name="shield"/><span>You’ll review all details before anything is submitted. This demonstration does not move real money.</span></div><Button className="full-btn" onClick={()=>setConfirm(true)}>Review and confirm <Icon name="chevron"/></Button></div>}
    </Card>
    <Card className="history-card"><div className="card-title-row"><div><Text as="h2">Recent activity</Text><Text as="p">All accounts</Text></div><button><Icon name="filter"/></button></div><TransactionRows/><Button variant="secondary" className="full-btn">View complete history</Button></Card></div>
    {confirm&&<div className="modal-layer"><div className="modal"><div className="modal-icon"><Icon name="swap"/></div><Text as="h2">Confirm your transfer</Text><Text as="p">Review these details carefully before submitting.</Text><div className="review-list"><span>From <strong>Savings •••• 4821</strong></span><span>To <strong>Recipient account</strong></span><span>Amount <strong>₹25,000.00</strong></span><span>Fee <strong>₹0.00</strong></span></div><div className="modal-actions"><Button variant="secondary" onClick={()=>setConfirm(false)}>Go back</Button><Button onClick={()=>{setConfirm(false);setSuccess(true)}}>Confirm transaction</Button></div></div></div>}
  </div></AppShell>
}

const flags = [
  ['FLG-82941','Velocity threshold exceeded','₹2,48,000','Critical','critical','12 Jun, 10:42','Open'],
  ['FLG-82938','Unusual recipient pattern','₹84,500','High','danger','12 Jun, 09:18','Investigating'],
  ['FLG-82927','Geolocation mismatch','₹32,100','Medium','warning','12 Jun, 08:54','Open'],
  ['FLG-82915','Multiple failed attempts','₹12,000','High','danger','11 Jun, 22:16','Under review'],
  ['FLG-82898','New device + high value','₹1,20,000','Medium','warning','11 Jun, 19:44','Open'],
]

function StaffTable({ go }: { go:(s:Screen)=>void }) {
  return <div className="table-wrap"><table><thead><tr><th>Flag ID</th><th>Rule / reason</th><th>Amount</th><th>Severity</th><th>Flagged at</th><th>Status</th><th/></tr></thead><tbody>{flags.map(f=><tr key={f[0]}><td><button className="table-link" onClick={()=>go('investigation')}>{f[0]}</button></td><td><strong>{f[1]}</strong><span>ACC •••• {Math.floor(Math.random()*8000+1000)}</span></td><td><strong>{f[2]}</strong></td><td><Badge tone={f[4] as 'critical'}>{f[3]}</Badge></td><td>{f[5]}</td><td><Badge tone="info">{f[6]}</Badge></td><td><button className="row-action" onClick={()=>go('investigation')}>Inspect <Icon name="chevron"/></button></td></tr>)}</tbody></table></div>
}

function Fraud({ screen, go, theme, setTheme }: { screen:Screen; go:(s:Screen)=>void; theme:Theme; setTheme:(t:Theme)=>void }) {
  return <AppShell staff screen={screen} onNavigate={go} theme={theme} setTheme={setTheme} title="Fraud Monitoring" subtitle="Live transaction risk intelligence and case management."><div className="page-content staff-content">
    <div className="alert-strip"><div><Icon name="activity"/><span>Risk engine is monitoring <strong>1,284 transactions</strong> in real time</span></div><Badge tone="success">All systems operational</Badge></div>
    <div className="kpi-grid">{[
      ['Open Flags','42','+8 today','alert','danger'],['Under Investigation','16','4 urgent','search','warning'],['Confirmed Cases','7','This month','shield','critical'],['False Positives','18','−12% vs last month','check','success']
    ].map(([label,value,meta,icon,tone])=><Card className="kpi" key={label}><div className={`kpi-icon ${tone}`}><Icon name={icon as IconName}/></div><div><span>{label}</span><strong>{value}</strong><small>{meta}</small></div></Card>)}</div>
    <div className="staff-charts"><Card className="trend-card"><div className="card-title-row"><div><Text as="h2">Fraud flag trend</Text><Text as="p">Flags generated over the last 30 days</Text></div><SelectField label=""><option>Last 30 days</option><option>Last 7 days</option></SelectField></div><div className="chart-kpis"><div><strong>184</strong><span>Total flags</span></div><div><strong className="risk-text">23</strong><span>High risk</span></div><div><strong>₹18.4L</strong><span>Value reviewed</span></div></div><MiniChart danger/></Card><Card className="risk-card"><div className="card-title-row"><div><Text as="h2">Risk distribution</Text><Text as="p">By severity</Text></div></div><div className="risk-ring"><div><strong>184</strong><span>Total flags</span></div></div><div className="risk-legend"><span><i className="critical"/>Critical <b>12</b></span><span><i className="high"/>High <b>28</b></span><span><i className="medium"/>Medium <b>56</b></span><span><i className="low"/>Low <b>88</b></span></div></Card></div>
    <Card className="flags-card"><div className="card-title-row"><div><Text as="h2">Recent fraud flags</Text><Text as="p">Prioritized by risk score and recency</Text></div><Button icon="plus" onClick={()=>go('investigation')}>Open investigation</Button></div><div className="filters"><div className="search-box"><Icon name="search"/><input placeholder="Search flag, account or rule…"/></div><SelectField label=""><option>All severity</option><option>Critical</option><option>High</option></SelectField><SelectField label=""><option>All statuses</option><option>Open</option><option>Investigating</option></SelectField><Button variant="secondary" icon="filter">More filters</Button></div><StaffTable go={go}/><div className="pagination"><span>Showing 1–5 of 42 flags</span><div><button disabled>Previous</button><button className="active">1</button><button>2</button><button>3</button><button>Next</button></div></div></Card>
  </div></AppShell>
}

function Investigation({ screen, go, theme, setTheme }: { screen:Screen; go:(s:Screen)=>void; theme:Theme; setTheme:(t:Theme)=>void }) {
  const [tab,setTab]=useState('Details')
  const [resolve,setResolve]=useState(false)
  return <AppShell staff screen={screen} onNavigate={go} theme={theme} setTheme={setTheme} title="Investigation #INV-1042" subtitle="Opened from fraud flag FLG-82941."><div className="page-content investigation-page">
    <div className="investigation-top"><button className="back-link" onClick={()=>go('fraud')}>← Back to Fraud Monitoring</button><div><Badge tone="warning">Under Investigation</Badge><span>Assigned to <strong>Maya Kapoor</strong></span><Button variant="secondary" icon="download">Export case</Button></div></div>
    <Card className="case-summary"><div className="case-risk"><div className="critical-shield"><Icon name="alert"/></div><div><span>CRITICAL SEVERITY</span><Text as="h2">Velocity threshold exceeded</Text><Text as="p">Six high-value transfers were initiated within nine minutes from a newly registered device.</Text></div></div><div className="case-amount"><span>Flagged amount</span><strong>₹2,48,000</strong><small>12 Jun 2025, 10:42 AM</small></div></Card>
    <div className="case-grid"><Card className="case-main"><div className="tabs line-tabs">{['Details','Investigation Notes','Activity Log'].map(t=><button className={tab===t?'active':''} onClick={()=>setTab(t)} key={t}>{t}</button>)}</div>
      {tab==='Details'&&<div className="case-details"><Text as="h3">Transaction information</Text><div className="detail-grid"><span>Transaction ID<strong>TXN-98200471</strong></span><span>Rule name<strong>TXN_VELOCITY_06</strong></span><span>Source account<strong>•••• 4821</strong></span><span>Destination account<strong>•••• 9084</strong></span><span>Channel<strong>Mobile Banking</strong></span><span>Device status<strong>New / untrusted</strong></span></div><div className="reason-box"><Icon name="alert"/><div><strong>Why this was flagged</strong><span>This is an unverified risk signal, not a confirmed fraud outcome. Investigation is required before resolution.</span></div></div><Text as="h3">Related activity</Text><div className="related-list">{['₹48,000 transfer initiated','₹55,000 transfer completed','New device enrolled'].map((x,i)=><div key={x}><i/><span><strong>{x}</strong><small>{`10:${42-i*3} AM • Mobile Banking`}</small></span><Badge tone={i===1?'danger':'warning'}>{i===1?'High risk':'Review'}</Badge></div>)}</div></div>}
      {tab==='Investigation Notes'&&<div className="notes-tab"><Text as="h3">Investigation findings</Text><textarea placeholder="Record evidence, customer contact details, and your assessment…"/><div className="note-history"><strong>Previous note</strong><span>12 Jun, 11:14 AM • Maya Kapoor</span><p>Initial account review started. Customer contact pending. Device fingerprint does not match the previous 90-day profile.</p></div></div>}
      {tab==='Activity Log'&&<div className="timeline">{['Investigation assigned to Maya Kapoor','Risk score recalculated: 94 / 100','Investigation created from FLG-82941','Transaction flagged by risk engine'].map((x,i)=><div key={x}><i className={i===0?'active':''}/><span><strong>{x}</strong><small>{12-i} Jun 2025 • {10+i}:42 AM</small></span></div>)}</div>}
    </Card>
    <aside className="case-side"><Card><Text as="h3">Case management</Text><SelectField label="Assigned investigator"><option>Maya Kapoor</option><option>Rahul Mehta</option><option>Fraud Ops Queue</option></SelectField><SelectField label="Proposed outcome"><option>Select outcome</option><option>Confirmed Fraud</option><option>False Positive</option><option>Inconclusive</option></SelectField><Field label="Next review date" type="date"/><Button className="full-btn">Save notes</Button><Button variant="danger" className="full-btn" onClick={()=>setResolve(true)}>Resolve investigation</Button></Card><Card><Text as="h3">Customer risk profile</Text><div className="risk-score"><strong>82</strong><span>High risk score</span></div><div className="profile-stats"><span>Account age <strong>4.2 years</strong></span><span>Prior flags <strong>2</strong></span><span>KYC status <Badge tone="success">Verified</Badge></span></div></Card></aside></div>
    {resolve&&<div className="modal-layer"><div className="modal"><div className="modal-icon danger"><Icon name="alert"/></div><Text as="h2">Resolve this investigation?</Text><Text as="p">This will finalize the case outcome and create an immutable audit event. Confirm that all evidence has been reviewed.</Text><div className="modal-actions"><Button variant="secondary" onClick={()=>setResolve(false)}>Cancel</Button><Button variant="danger" onClick={()=>{setResolve(false);go('fraud')}}>Confirm resolution</Button></div></div></div>}
  </div></AppShell>
}

const auditRows = [
  ['12 Jun, 11:42','Maya Kapoor','Investigation updated','TXN-98200471','Open','Under Review','Staff'],
  ['12 Jun, 10:46','Risk Engine','Fraud flag created','TXN-98200471','—','Open','System'],
  ['12 Jun, 09:18','Rahul Mehta','Flag assigned','TXN-48271920','Open','Investigating','Staff'],
  ['12 Jun, 08:32','Alex Johnson','Transfer initiated','TXN-77128921','—','Pending','Customer'],
  ['11 Jun, 22:20','Maya Kapoor','Investigation resolved','TXN-39182744','Under Review','False Positive','Staff'],
]

function Audit({ screen, go, theme, setTheme }: { screen:Screen; go:(s:Screen)=>void; theme:Theme; setTheme:(t:Theme)=>void }) {
  return <AppShell staff screen={screen} onNavigate={go} theme={theme} setTheme={setTheme} title="Audit Logs & Reports" subtitle="Trace every system, staff, and customer action."><div className="page-content">
    <div className="report-summary">{[['Total Events','12,840','+12.8%','file'],['Staff Actions','2,419','18.8% of events','shield'],['Customer Actions','9,842','76.6% of events','user'],['System Events','579','4.6% of events','activity']].map(([a,b,c,d])=><Card key={a}><i><Icon name={d as IconName}/></i><div><span>{a}</span><strong>{b}</strong><small>{c}</small></div></Card>)}</div>
    <div className="report-charts"><Card><div className="card-title-row"><div><Text as="h2">Transaction & fraud trend</Text><Text as="p">Event volume across the last 30 days</Text></div><Badge tone="info">Live report</Badge></div><MiniChart/></Card><Card><div className="card-title-row"><div><Text as="h2">Action source</Text><Text as="p">By actor category</Text></div></div><div className="horizontal-bars"><span>Customer actions <i><b style={{width:'77%'}}/></i><strong>77%</strong></span><span>Staff actions <i><b style={{width:'19%'}}/></i><strong>19%</strong></span><span>System events <i><b style={{width:'4%'}}/></i><strong>4%</strong></span></div></Card></div>
    <Card className="audit-card"><div className="card-title-row"><div><Text as="h2">Audit event log</Text><Text as="p">Immutable history of platform activity</Text></div><Button variant="secondary" icon="download">Export CSV</Button></div><div className="filters"><div className="search-box"><Icon name="search"/><input placeholder="Search user, action or transaction…"/></div><SelectField label=""><option>All actors</option><option>Staff</option><option>Customer</option></SelectField><SelectField label=""><option>All actions</option><option>Transactions</option><option>Investigations</option></SelectField><Field label="" type="date"/></div><div className="table-wrap"><table><thead><tr><th>Date / Time</th><th>User</th><th>Action</th><th>Transaction ID</th><th>Old status</th><th>New status</th><th>Details</th></tr></thead><tbody>{auditRows.map(r=><tr key={r[0]+r[2]}><td>{r[0]}</td><td><strong>{r[1]}</strong><Badge tone={r[6]==='Staff'?'info':r[6]==='System'?'neutral':'success'}>{r[6]}</Badge></td><td>{r[2]}</td><td className="mono">{r[3]}</td><td>{r[4]}</td><td><Badge tone="info">{r[5]}</Badge></td><td><button className="row-action">View <Icon name="chevron"/></button></td></tr>)}</tbody></table></div><div className="pagination"><span>Showing 1–5 of 12,840 events</span><div><button disabled>Previous</button><button className="active">1</button><button>2</button><button>3</button><button>Next</button></div></div></Card>
  </div></AppShell>
}

function Settings({ screen, go, theme, setTheme }: { screen:Screen; go:(s:Screen)=>void; theme:Theme; setTheme:(t:Theme)=>void }) {
  const [saved,setSaved]=useState(false)
  return <AppShell screen={screen} onNavigate={go} theme={theme} setTheme={setTheme} title="Profile & Settings" subtitle="Manage your personal details, preferences, and security."><div className="page-content settings-layout">
    <Card className="settings-nav"><div className="profile-large"><div className="avatar">AJ</div><strong>Alex Johnson</strong><span>Customer since 2021</span><Badge tone="success">Verified profile</Badge></div><nav>{[['user','Personal information'],['lock','Password & security'],['bell','Notifications'],['shield','Privacy & security'],['sun','Appearance']].map(([i,l],n)=><button className={n===0?'active':''} key={l}><Icon name={i as IconName}/>{l}<Icon name="chevron"/></button>)}</nav></Card>
    <div className="settings-main">{saved&&<div className="toast"><Icon name="check"/><div><strong>Changes saved</strong><span>Your profile was updated successfully.</span></div><button onClick={()=>setSaved(false)}><Icon name="close"/></button></div>}
      <Card><div className="settings-section-title"><div><Text as="h2">Personal information</Text><Text as="p">Keep your profile details accurate and up to date.</Text></div><Badge tone="success"><Icon name="shield"/> KYC verified</Badge></div><div className="profile-edit"><div className="avatar xl">AJ</div><div><Button variant="secondary">Change photo</Button><span>JPG or PNG. Maximum 2MB.</span></div></div><div className="form-grid"><Field label="First name" defaultValue="Alex"/><Field label="Last name" defaultValue="Johnson"/><Field label="Email address" defaultValue="alex.johnson@example.com" type="email"/><Field label="Phone number" defaultValue="+91 98765 43210"/><Field label="Customer ID" defaultValue="SB-104829" helper="Customer ID cannot be changed"/><Field label="Account role" defaultValue="Primary account holder"/></div></Card>
      <Card><div className="settings-section-title"><div><Text as="h2">Security preferences</Text><Text as="p">Control how your account is protected.</Text></div></div>{[['Two-factor authentication','Add an extra layer of protection when signing in.',true],['Biometric login','Use device biometrics on supported devices.',true],['Login alerts','Get notified when a new device signs in.',true]].map(([a,b,c])=><div className="toggle-row" key={a as string}><div><strong>{a}</strong><span>{b}</span></div><label className="toggle"><input type="checkbox" defaultChecked={c as boolean}/><i/></label></div>)}<Button variant="secondary" icon="lock">Change password</Button></Card>
      <Card><div className="settings-section-title"><div><Text as="h2">Appearance</Text><Text as="p">Choose how SecureBank looks on this device.</Text></div></div><div className="theme-options"><button className={theme==='light'?'active':''} onClick={()=>setTheme('light')}><div className="theme-preview light-preview"><i/><span/><span/></div><strong><Icon name="sun"/>Light mode</strong></button><button className={theme==='dark'?'active':''} onClick={()=>setTheme('dark')}><div className="theme-preview dark-preview"><i/><span/><span/></div><strong><Icon name="moon"/>Dark mode</strong></button></div></Card>
      <div className="settings-actions"><Button variant="secondary">Cancel</Button><Button onClick={()=>{setSaved(true);window.scrollTo({top:0,behavior:'smooth'})}}>Save changes</Button></div>
    </div>
  </div></AppShell>
}

function ErrorPage({ go, theme, setTheme }: { go:(s:Screen)=>void; theme:Theme; setTheme:(t:Theme)=>void }) {
  return <div className="error-page"><header><Logo/><button className="icon-btn" onClick={()=>setTheme(theme==='dark'?'light':'dark')}><Icon name={theme==='dark'?'sun':'moon'}/></button></header><main><div className="error-art"><span>4</span><div className="error-shield"><Icon name="shield" size={58}/></div><span>4</span></div><Text as="h1">Page not found</Text><Text as="p">The page you’re looking for may have moved, or you may not have permission to view it.</Text><div><Button onClick={()=>go('landing')}>Back to Home</Button><Button variant="secondary" onClick={()=>go('dashboard')}>Go to Dashboard</Button></div><section className="state-showcase"><div><i><Icon name="file"/></i><strong>Nothing here yet</strong><span>Empty states stay calm and helpful.</span></div><div><i className="spinner large"/><strong>Loading securely</strong><span>Data is being protected in transit.</span></div><div><i><Icon name="lock"/></i><strong>Permission required</strong><span>Ask an administrator for access.</span></div><div><i><Icon name="alert"/></i><strong>Something went wrong</strong><span>Try again or contact support.</span></div></section></main></div>
}

export default function App() {
  const [screen, setScreen] = useState<Screen>('landing')
  const [theme, setTheme] = useState<Theme>('dark')
  const page = useMemo(() => {
    const shared = { screen, go: setScreen, theme, setTheme }
    if (screen === 'landing') return <Landing go={setScreen}/>
    if (screen === 'login') return <Login go={setScreen}/>
    if (screen === 'dashboard') return <Dashboard {...shared}/>
    if (screen === 'transactions') return <Transactions {...shared}/>
    if (screen === 'fraud') return <Fraud {...shared}/>
    if (screen === 'investigation') return <Investigation {...shared}/>
    if (screen === 'audit') return <Audit {...shared}/>
    if (screen === 'settings') return <Settings {...shared}/>
    return <ErrorPage go={setScreen} theme={theme} setTheme={setTheme}/>
  }, [screen, theme])
  return <div className={theme} data-theme={theme}>{page}</div>
}
