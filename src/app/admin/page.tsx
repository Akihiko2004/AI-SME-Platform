import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Users, DollarSign, CalendarCheck, TrendingUp } from 'lucide-react';
import { Button } from '@/components/ui/button';

export default function AdminDashboard() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold tracking-tight text-slate-900">Tổng quan hôm nay</h1>
        <Button className="bg-blue-600 hover:bg-blue-700">+ Tạo lịch mới</Button>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card className="border-slate-200 shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
            <CardTitle className="text-sm font-medium text-slate-500">Doanh thu</CardTitle>
            <DollarSign className="w-4 h-4 text-slate-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-slate-900">12.500.000 đ</div>
            <p className="text-xs text-emerald-500 flex items-center mt-1 font-medium"><TrendingUp className="w-3 h-3 mr-1"/> +15% so với hôm qua</p>
          </CardContent>
        </Card>
        <Card className="border-slate-200 shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
            <CardTitle className="text-sm font-medium text-slate-500">Lịch hẹn hoàn thành</CardTitle>
            <CalendarCheck className="w-4 h-4 text-slate-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-slate-900">24</div>
            <p className="text-xs text-slate-500 mt-1 font-medium"><span className="text-amber-500">4 lịch đang chờ</span></p>
          </CardContent>
        </Card>
        <Card className="border-slate-200 shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
            <CardTitle className="text-sm font-medium text-slate-500">Khách hàng mới</CardTitle>
            <Users className="w-4 h-4 text-slate-400" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-slate-900">8</div>
            <p className="text-xs text-slate-500 mt-1 font-medium">Trong ngày hôm nay</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card className="col-span-2 border-slate-200 shadow-sm">
          <CardHeader>
            <CardTitle>Biểu đồ doanh thu tuần</CardTitle>
          </CardHeader>
          <CardContent className="h-72 flex items-center justify-center bg-slate-50 rounded-lg border border-dashed border-slate-200 mx-6 mb-6">
            <div className="text-center text-slate-400">
              <TrendingUp className="w-8 h-8 mx-auto mb-2 text-slate-300" />
              <p>Chart Placeholder</p>
            </div>
          </CardContent>
        </Card>
        <Card className="border-slate-200 shadow-sm">
          <CardHeader>
            <CardTitle>Lịch sắp tới</CardTitle>
          </CardHeader>
          <CardContent>
             <div className="space-y-4">
               {[1,2,3, 4, 5].map((i) => (
                 <div key={i} className="flex items-center justify-between border-b border-slate-100 pb-4 last:border-0 last:pb-0">
                    <div>
                      <p className="font-semibold text-sm text-slate-900">Nguyễn Văn Khách {i}</p>
                      <p className="text-xs text-slate-500 mt-0.5">Massage Body (90p)</p>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-bold text-slate-700">14:00</p>
                      <span className="inline-block mt-1 text-[10px] font-medium px-2 py-0.5 bg-amber-100 text-amber-800 rounded-full">Chờ làm</span>
                    </div>
                 </div>
               ))}
             </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
