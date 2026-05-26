import React from "react";
import { Link } from "react-router-dom";
import {
  ArrowRight,
  Blocks,
  CheckCheck,
  Coins,
  GitBranch,
  Layers3,
  LayoutPanelLeft,
  ReceiptText,
  ShieldCheck,
  Store,
  Ticket,
  Wallet,
} from "lucide-react";
import { Badge } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import { Card } from "../../components/ui/card";
import { ImageWithFallback } from "../../components/figma/ImageWithFallback";

const projectPillars = [
  {
    icon: LayoutPanelLeft,
    title: "Frontend",
    stack: "React 18, Vite 6, Tailwind CSS 4, Web3Auth",
    description:
      "Public discovery flows, user dashboards, admin surfaces, deposit redirects, and verifier tools live in the client app.",
  },
  {
    icon: Layers3,
    title: "Backend",
    stack: "Express 5, MongoDB, JWT, SIWE, Ethers 6",
    description:
      "The API manages auth, event operations, marketplace workflows, VNPay deposits, and synchronized query models.",
  },
  {
    icon: Blocks,
    title: "Smart Contracts",
    stack: "Solidity 0.8.20, Hardhat, OpenZeppelin",
    description:
      "Fund, Ticket, and Marketplace contracts handle crowdfunding, NFT ticket issuance, resale, royalties, refunds, and settlement rules.",
  },
];

const platformFlows = [
  {
    step: "01",
    title: "Create and fund events",
    description:
      "Organizers configure funding goals, ticket pricing, thresholds, and stake requirements before the event goes live.",
    icon: Coins,
  },
  {
    step: "02",
    title: "Mint NFT tickets",
    description:
      "Once an event reaches the right state, tickets are minted on-chain and made available for primary sales.",
    icon: Ticket,
  },
  {
    step: "03",
    title: "Trade with guardrails",
    description:
      "Buyers can hold, transfer, or relist tickets while marketplace rules enforce royalties, status checks, and payment splits.",
    icon: Store,
  },
  {
    step: "04",
    title: "Verify and settle",
    description:
      "Verifiers check attendees in, backend workers sync chain activity, and the platform supports refunds, rewards, and revenue release.",
    icon: CheckCheck,
  },
];

const capabilityGrid = [
  {
    icon: Wallet,
    title: "Wallet-first access",
    description:
      "SIWE and Web3Auth flows are built in, so authentication matches the wallet-based product model.",
  },
  {
    icon: ShieldCheck,
    title: "Fraud-resistant ticketing",
    description:
      "NFT ownership, verifier check-in, ticket state transitions, and refund handling reduce counterfeit and duplicate-entry risks.",
  },
  {
    icon: Store,
    title: "Secondary marketplace",
    description:
      "Listings, capped pricing logic, royalty routing, and ownership transfers are all part of the smart-contract flow.",
  },
  {
    icon: Coins,
    title: "Crowdfunding model",
    description:
      "Investors can contribute to event funding, receive shares, and claim rewards based on event outcomes.",
  },
  {
    icon: ReceiptText,
    title: "Deposit infrastructure",
    description:
      "VNPay deposit flows support fiat-friendly top-ups and wallet balance usage across the application.",
  },
  {
    icon: GitBranch,
    title: "On-chain data sync",
    description:
      "Indexers and processors materialize blockchain events into MongoDB so the UI can query stable, app-friendly views.",
  },
];

const teamMembers = [
  { handle: "truongtrongdat94", profile: "https://github.com/truongtrongdat94" },
  { handle: "truongtrongdat94", profile: "https://github.com/truongtrongdat94" },
  { handle: "NhanVT24", profile: "https://github.com/NhanVT24" },
  { handle: "bincasau", profile: "https://github.com/bincasau" },
  { handle: "NguyenVu3105", profile: "https://github.com/NguyenVu3105" },
];

const stackGroups = [
  {
    label: "Client",
    items: ["React 18", "React Router 7", "Tailwind CSS 4", "MUI", "Radix UI"],
  },
  {
    label: "Server",
    items: ["Express 5", "MongoDB", "Mongoose", "JWT", "Swagger/OpenAPI"],
  },
  {
    label: "Chain",
    items: ["Solidity", "Hardhat", "OpenZeppelin", "Ethers 6", "Sepolia-ready"],
  },
];

export const About: React.FC = () => {
  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <section className="relative overflow-hidden border-b border-slate-800/80 bg-slate-950">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(34,211,238,0.14),transparent_32%),radial-gradient(circle_at_bottom_right,rgba(16,185,129,0.12),transparent_28%)]" />
        <div className="relative z-10 mx-auto grid max-w-7xl gap-12 px-4 py-16 sm:px-6 lg:grid-cols-[1.15fr_0.85fr] lg:px-8 lg:py-20">
          <div className="max-w-3xl">
            <div className="mb-5 flex flex-wrap gap-2">
              <Badge className="border border-cyan-400/30 bg-cyan-500/10 text-cyan-200 hover:bg-cyan-500/10">
                Web3 Event Platform
              </Badge>
              <Badge className="border border-emerald-400/30 bg-emerald-500/10 text-emerald-200 hover:bg-emerald-500/10">
                Crowdfunding + NFT Ticketing
              </Badge>
            </div>

            <h1 className="text-4xl font-semibold tracking-tight text-white sm:text-5xl lg:text-6xl">
              About EventChain
            </h1>

            <p className="mt-5 max-w-2xl text-lg leading-8 text-slate-200">
              EventChain is a comprehensive event funding and ticketing platform 
              that combines crowdfunding, NFT tickets, verifier check-in, 
              marketplace resale, and admin operations seamlessly in one ecosystem.
            </p>

            <div className="mt-8 grid gap-4 sm:grid-cols-3">
              <div className="border-l-2 border-cyan-400 pl-4">
                <div className="text-2xl font-semibold text-white">3</div>
                <p className="mt-1 text-sm text-slate-300">
                  Core layers: frontend, backend, contracts
                </p>
              </div>
              <div className="border-l-2 border-emerald-400 pl-4">
                <div className="text-2xl font-semibold text-white">6+</div>
                <p className="mt-1 text-sm text-slate-300">
                  Core product capabilities in active flows
                </p>
              </div>
              <div className="border-l-2 border-amber-400 pl-4">
                <div className="text-2xl font-semibold text-white">1</div>
                <p className="mt-1 text-sm text-slate-300">
                  Unified platform coordinating app, API, and chain logic
                </p>
              </div>
            </div>

            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Button asChild size="lg" className="bg-cyan-600 hover:bg-cyan-500">
                <Link to="/explore">
                  Explore Events
                  <ArrowRight className="w-4 h-4" />
                </Link>
              </Button>
              <Button
                asChild
                size="lg"
                variant="outline"
                className="border-slate-700 bg-slate-950/60 text-slate-100 hover:bg-slate-900"
              >
                <Link to="/marketplace">Open Marketplace</Link>
              </Button>
            </div>
          </div>

          <div className="flex items-end">
            <div className="w-full overflow-hidden rounded-xl border border-slate-800/80 bg-slate-950/80 backdrop-blur-sm">
              <div className="aspect-[16/10] border-b border-slate-800 bg-slate-950">
                <ImageWithFallback
                  src="/favicon.jpg"
                  alt="EventChain project visual"
                  className="h-full w-full object-cover object-left"
                />
              </div>
              <div className="p-5">
                <div className="flex items-center justify-between gap-3 border-b border-slate-800 pb-4">
                  <div>
                    <p className="text-sm font-medium text-cyan-300">
                      Platform snapshot
                    </p>
                    <h2 className="mt-1 text-xl font-semibold text-white">
                      Event funding, ticketing, and chain sync in one ecosystem
                    </h2>
                  </div>
                  <div className="hidden h-12 w-12 items-center justify-center rounded-lg border border-slate-700 bg-slate-900 sm:flex">
                    <Blocks className="h-6 w-6 text-cyan-300" />
                  </div>
                </div>
                <div className="grid gap-4 pt-4 sm:grid-cols-2">
                  <div>
                    <p className="text-xs uppercase tracking-[0.18em] text-slate-400">
                      Public routes
                    </p>
                    <p className="mt-2 text-sm leading-6 text-slate-300">
                      Home, explore, marketplace, event detail, ticket detail,
                      about, FAQ, terms, and privacy.
                    </p>
                  </div>
                  <div>
                    <p className="text-xs uppercase tracking-[0.18em] text-slate-400">
                      Protected surfaces
                    </p>
                    <p className="mt-2 text-sm leading-6 text-slate-300">
                      User dashboards, verifier tools, admin analytics, finance,
                      fraud monitoring, and profile flows.
                    </p>
                  </div>
                  <div>
                    <p className="text-xs uppercase tracking-[0.18em] text-slate-400">
                      API domains
                    </p>
                    <p className="mt-2 text-sm leading-6 text-slate-300">
                      Auth, events, tickets, marketplace, users, admin, deposits,
                      and health endpoints.
                    </p>
                  </div>
                  <div>
                    <p className="text-xs uppercase tracking-[0.18em] text-slate-400">
                      Contract domains
                    </p>
                    <p className="mt-2 text-sm leading-6 text-slate-300">
                      Funding lifecycle, ticket minting and purchase, resale,
                      royalties, refunds, and reward release.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="border-b border-slate-900 bg-slate-950">
        <div className="mx-auto max-w-7xl px-4 py-14 sm:px-6 lg:px-8">
          <div className="mb-8 max-w-3xl">
            <p className="text-sm font-medium uppercase tracking-[0.18em] text-cyan-300">
              Architecture
            </p>
            <h2 className="mt-3 text-3xl font-semibold text-white">
              The platform is organized as three tightly linked delivery layers
            </h2>
            <p className="mt-4 text-base leading-7 text-slate-400">
              Our architecture is built on a seamless integration: a unified
              system coordinates the user-facing app, the service layer, and the 
              on-chain logic so event funding and ticketing operate flawlessly together.
            </p>
          </div>

          <div className="grid gap-5 lg:grid-cols-3">
            {projectPillars.map((pillar) => (
              <Card
                key={pillar.title}
                className="border-slate-800 bg-slate-900/60 p-6 text-slate-100"
              >
                <div className="flex items-center gap-4">
                  <div className="flex h-11 w-11 items-center justify-center border border-slate-700 bg-slate-950">
                    <pillar.icon className="h-5 w-5 text-cyan-300" />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-white">
                      {pillar.title}
                    </h3>
                    <p className="text-sm text-slate-400">{pillar.stack}</p>
                  </div>
                </div>
                <p className="mt-5 text-sm leading-6 text-slate-300">
                  {pillar.description}
                </p>
              </Card>
            ))}
          </div>
        </div>
      </section>

      <section className="border-b border-slate-900 bg-slate-900/40">
        <div className="mx-auto max-w-7xl px-4 py-14 sm:px-6 lg:px-8">
          <div className="mb-8 max-w-3xl">
            <p className="text-sm font-medium uppercase tracking-[0.18em] text-emerald-300">
              Product Flow
            </p>
            <h2 className="mt-3 text-3xl font-semibold text-white">
              From fundraising to check-in, the platform follows a clear chain-backed lifecycle
            </h2>
          </div>

          <div className="grid gap-5 lg:grid-cols-4">
            {platformFlows.map((flow) => (
              <div
                key={flow.step}
                className="border border-slate-800 bg-slate-900/50 p-6"
              >
                <div className="flex items-center justify-between gap-4">
                  <span className="text-sm font-semibold text-emerald-300">
                    STEP {flow.step}
                  </span>
                  <flow.icon className="h-5 w-5 text-slate-400" />
                </div>
                <h3 className="mt-4 text-lg font-semibold text-white">
                  {flow.title}
                </h3>
                <p className="mt-3 text-sm leading-6 text-slate-300">
                  {flow.description}
                </p>
              </div>
            ))}
          </div>

          <div className="mt-8 overflow-hidden rounded-xl border border-slate-800 bg-slate-950/70">
            <div className="grid lg:grid-cols-[1.05fr_0.95fr]">
              <div className="p-6 lg:p-8">
                <p className="text-sm font-medium uppercase tracking-[0.18em] text-emerald-300">
                  Project visual
                </p>
                <h3 className="mt-3 text-2xl font-semibold text-white">
                  A single product surface for fundraising, ticketing, resale, and verification
                </h3>
                <p className="mt-4 max-w-xl text-sm leading-7 text-slate-300">
                  The platform is designed to connect organizers, attendees,
                  investors, verifiers, and admins inside one coordinated flow
                  instead of splitting each responsibility into separate tools.
                </p>
              </div>
              <div className="min-h-[220px] border-t border-slate-800 bg-slate-950 lg:border-l lg:border-t-0">
                <ImageWithFallback
                  src="/favicon.jpg"
                  alt="EventChain banner"
                  className="h-full w-full object-cover object-left"
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="border-b border-slate-900 bg-slate-950">
        <div className="mx-auto max-w-7xl px-4 py-14 sm:px-6 lg:px-8">
          <div className="grid gap-10 lg:grid-cols-[1.1fr_0.9fr]">
            <div>
              <p className="text-sm font-medium uppercase tracking-[0.18em] text-amber-300">
                Capabilities
              </p>
              <h2 className="mt-3 text-3xl font-semibold text-white">
                Our scope provides much more than a ticket marketplace
              </h2>
              <p className="mt-4 max-w-2xl text-base leading-7 text-slate-400">
                EventChain brings together event operations, user identity,
                NFT ticketing, investor participation, payment flows, and
                blockchain indexing. The result is a robust product platform
                ready for real-world adoption.
              </p>

              <div className="mt-8 grid gap-4 sm:grid-cols-2">
                {capabilityGrid.map((item) => (
                  <div
                    key={item.title}
                    className="border border-slate-800 bg-slate-900/50 p-5"
                  >
                    <div className="flex items-center gap-3">
                      <item.icon className="h-5 w-5 text-amber-300" />
                      <h3 className="font-semibold text-white">{item.title}</h3>
                    </div>
                    <p className="mt-3 text-sm leading-6 text-slate-300">
                      {item.description}
                    </p>
                  </div>
                ))}
              </div>
            </div>

            <div className="border border-slate-800 bg-slate-900/60 p-6">
              <div className="flex items-center justify-between gap-4 border-b border-slate-800 pb-4">
                <div>
                  <p className="text-sm font-medium text-amber-300">
                    Tech stack
                  </p>
                  <h3 className="mt-1 text-xl font-semibold text-white">
                    The platform spans modern web, API, and chain tooling
                  </h3>
                </div>
              </div>

              <div className="mt-5 space-y-5">
                {stackGroups.map((group) => (
                  <div key={group.label}>
                    <p className="text-xs uppercase tracking-[0.18em] text-slate-500">
                      {group.label}
                    </p>
                    <div className="mt-3 flex flex-wrap gap-2">
                      {group.items.map((item) => (
                        <Badge
                          key={item}
                          className="border border-slate-700 bg-slate-950 text-slate-200 hover:bg-slate-950"
                        >
                          {item}
                        </Badge>
                      ))}
                    </div>
                  </div>
                ))}
              </div>

              <div className="mt-8 border-t border-slate-800 pt-5">
                <p className="text-sm leading-6 text-slate-300">
                  Our technical infrastructure reflects this breadth: combining
                  a lightning-fast frontend and API with rigorous smart
                  contract deployments, reliable backend workers, and real-time blockchain
                  synchronization.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="border-b border-slate-900 bg-slate-950">
        <div className="mx-auto max-w-7xl px-4 py-14 sm:px-6 lg:px-8">
          <div className="mb-8 max-w-3xl">
            <p className="text-sm font-medium uppercase tracking-[0.18em] text-cyan-300">
              Contributors
            </p>
            <h2 className="mt-3 text-3xl font-semibold text-white">
              Team profiles linked from GitHub
            </h2>
            <p className="mt-4 text-base leading-7 text-slate-400">
              Contributor handles and profile links for the project team.
            </p>
          </div>

          <div className="mx-auto max-w-4xl space-y-5">
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {teamMembers.slice(0, 3).map((member) => (
                <a
                  key={member.handle}
                  href={member.profile}
                  target="_blank"
                  rel="noreferrer"
                  className="group overflow-hidden rounded-lg border border-slate-800 bg-slate-900/60 transition-colors hover:border-cyan-400/50"
                >
                  <div className="mx-auto mt-4 h-24 w-24 overflow-hidden rounded-full border border-slate-700 bg-slate-950">
                    <ImageWithFallback
                      src={`https://github.com/${member.handle}.png?size=400`}
                      alt={member.handle}
                      className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-[1.03]"
                    />
                  </div>
                  <div className="p-3 text-center">
                    <div className="flex items-center justify-center">
                      <h3 className="text-sm font-semibold text-white">
                        @{member.handle}
                      </h3>
                    </div>
                  </div>
                </a>
              ))}
            </div>

            <div className="flex flex-wrap justify-center gap-4">
              {teamMembers.slice(3).map((member) => (
                <a
                  key={member.handle}
                  href={member.profile}
                  target="_blank"
                  rel="noreferrer"
                  className="group w-full max-w-[220px] overflow-hidden rounded-lg border border-slate-800 bg-slate-900/60 transition-colors hover:border-cyan-400/50"
                >
                  <div className="mx-auto mt-4 h-24 w-24 overflow-hidden rounded-full border border-slate-700 bg-slate-950">
                    <ImageWithFallback
                      src={`https://github.com/${member.handle}.png?size=400`}
                      alt={member.handle}
                      className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-[1.03]"
                    />
                  </div>
                  <div className="p-3 text-center">
                    <div className="flex items-center justify-center">
                      <h3 className="text-sm font-semibold text-white">
                        @{member.handle}
                      </h3>
                    </div>
                  </div>
                </a>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="bg-slate-950">
        <div className="mx-auto max-w-7xl px-4 py-14 sm:px-6 lg:px-8">
          <div className="flex flex-col gap-6 border border-slate-800 bg-slate-900/60 p-8 lg:flex-row lg:items-center lg:justify-between">
            <div className="max-w-3xl">
              <p className="text-sm font-medium uppercase tracking-[0.18em] text-emerald-300">
                Next step
              </p>
              <h2 className="mt-3 text-3xl font-semibold text-white">
                Explore the experiences the platform was built to deliver
              </h2>
              <p className="mt-4 text-base leading-7 text-slate-400">
                Browse public events, inspect ticket listings, or continue into
                the marketplace to discover how the user-facing side of the system is
                presented.
              </p>
            </div>

            <div className="flex flex-col gap-3 sm:flex-row">
              <Button asChild size="lg" className="bg-emerald-600 hover:bg-emerald-500">
                <Link to="/explore">
                  Explore Events
                  <ArrowRight className="w-4 h-4" />
                </Link>
              </Button>
              <Button
                asChild
                size="lg"
                variant="outline"
                className="border-slate-700 bg-slate-950 text-slate-100 hover:bg-slate-900"
              >
                <Link to="/marketplace">Browse Marketplace</Link>
              </Button>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};
