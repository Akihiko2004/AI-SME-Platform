"use client";
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { CalendarDays, Wallet, User } from 'lucide-react';
import { cn } from '@/lib/utils';

export function BottomNav() {
  const pathname = usePathname();
  
  const navItems = [
    { name: 'Lịch hôm nay', href: '/therapist', icon: CalendarDays },
    { name: 'Thu nhập', href: '/therapist/earnings', icon: Wallet },
    { name: 'Hồ sơ', href: '/therapist/profile', icon: User },
  ];

  return (
    <div className="fixed bottom-0 w-full bg-white border-t border-slate-200 pb-safe sm:pb-0 z-50 shadow-[0_-2px_10px_rgba(0,0,0,0.05)]">
      <div className="flex justify-around items-center h-16 max-w-md mx-auto">
        {navItems.map((item) => {
          const isActive = pathname === item.href;
          const Icon = item.icon;
          return (
            <Link key={item.name} href={item.href} className="flex-1 flex flex-col items-center justify-center h-full">
              <Icon size={24} className={cn("mb-1 transition-colors duration-200", isActive ? "text-blue-600" : "text-slate-400")} />
              <span className={cn("text-[10px] font-medium transition-colors duration-200", isActive ? "text-blue-600" : "text-slate-500")}>
                {item.name}
              </span>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
