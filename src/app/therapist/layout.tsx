import { BottomNav } from '@/components/therapist/BottomNav';

export default function TherapistLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex flex-col min-h-screen bg-slate-100 text-slate-900 font-sans pb-16">
      <main className="flex-1 overflow-y-auto max-w-md mx-auto w-full bg-white shadow-xl ring-1 ring-slate-200 min-h-screen relative">
        {children}
      </main>
      <BottomNav />
    </div>
  );
}
