import Link from 'next/link';
import { Button } from '@/components/ui/button';

export default function Home() {
  return (
    <div className="flex h-screen flex-col items-center justify-center bg-slate-50 p-4">
      <div className="bg-white p-10 rounded-2xl shadow-xl max-w-md w-full text-center border border-slate-100">
        <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-6">
          <span className="text-2xl text-blue-600">✨</span>
        </div>
        <h1 className="text-3xl font-extrabold mb-2 text-slate-900">SpaSME</h1>
        <p className="text-slate-500 mb-8 text-sm">Hệ thống quản lý Spa & Salon thông minh</p>
        
        <div className="flex flex-col gap-4 w-full">
          <Link href="/admin" className="w-full">
            <Button className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium" size="lg">Đăng nhập Lễ tân / Quản lý</Button>
          </Link>
          <Link href="/therapist" className="w-full">
            <Button variant="outline" className="w-full border-slate-200 text-slate-700 hover:bg-slate-50 font-medium" size="lg">Đăng nhập Thợ (Mobile)</Button>
          </Link>
        </div>
      </div>
    </div>
  );
}
