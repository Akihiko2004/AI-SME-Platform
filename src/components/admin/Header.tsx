import { Bell, Search } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';

export function Header() {
  return (
    <header className="h-16 border-b bg-white flex items-center justify-between px-6 z-10 relative">
      <div className="flex items-center bg-slate-50 rounded-lg px-3 w-64 lg:w-96 border border-slate-200">
        <Search size={18} className="text-slate-400" />
        <Input type="text" placeholder="Tìm số điện thoại khách..." className="border-0 bg-transparent shadow-none focus-visible:ring-0" />
      </div>
      <div className="flex items-center gap-4">
        <button className="relative p-2 rounded-full hover:bg-slate-100 transition-colors">
          <Bell size={20} className="text-slate-600" />
          <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full border-2 border-white"></span>
        </button>
        <div className="h-8 w-px bg-slate-200 mx-2"></div>
        <div className="flex items-center gap-3">
          <div className="hidden md:block text-right">
            <p className="text-sm font-semibold text-slate-900">Lễ tân 01</p>
            <p className="text-xs text-slate-500">Ca sáng</p>
          </div>
          <Avatar className="h-9 w-9 border">
            <AvatarImage src="https://github.com/shadcn.png" />
            <AvatarFallback>LT</AvatarFallback>
          </Avatar>
        </div>
      </div>
    </header>
  );
}
