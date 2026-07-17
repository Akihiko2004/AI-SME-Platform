"use client";
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { LayoutDashboard, Calendar, Users, Briefcase, Settings } from 'lucide-react';
import { cn } from '@/lib/utils';

export function Sidebar() {
  const pathname = usePathname();
  
  const navItems = [
    { name: 'Dashboard', href: '/admin', icon: LayoutDashboard },
    { name: 'Lịch Hẹn', href: '/admin/calendar', icon: Calendar },
    { name: 'Khách Hàng', href: '/admin/customers', icon: Users },
    { name: 'Dịch Vụ', href: '/admin/services', icon: Briefcase },
    { name: 'Cài Đặt', href: '/admin/settings', icon: Settings },
  ];

  return (
    <div className="hidden md:flex w-64 flex-col bg-white border-r h-full">
      <div className="p-6 border-b flex items-center justify-center">
        <h2 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-600 to-teal-500">SpaSME</h2>
      </div>
      <nav className="flex-1 p-4 space-y-2">
        {navItems.map((item) => {
          const isActive = pathname === item.href || (pathname.startsWith(item.href) && item.href !== '/admin');
          const Icon = item.icon;
          return (
            <Link key={item.name} href={item.href}>
              <div className={cn("flex items-center gap-3 px-4 py-3 rounded-lg transition-all duration-200", isActive ? "bg-slate-900 text-white shadow-md" : "text-slate-600 hover:bg-slate-100 hover:text-slate-900")}>
                <Icon size={20} className={isActive ? "text-blue-400" : ""} />
                <span className="font-medium">{item.name}</span>
              </div>
            </Link>
          );
        })}
      </nav>
      <div className="p-4 border-t text-xs text-center text-slate-400">
        v1.0.0 - AI Platform
      </div>
    </div>
  );
}
