import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { AlertCircle, CheckCircle2 } from 'lucide-react';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';

export default function TherapistToday() {
  return (
    <div className="p-4 space-y-6">
      {/* Header Profile */}
      <div className="flex items-center justify-between pt-4 pb-2 border-b border-slate-100">
        <div>
          <p className="text-sm text-slate-500">Thứ Năm, 12 Tháng 10</p>
          <h1 className="text-2xl font-bold text-slate-900">Chào, Lan Anh!</h1>
        </div>
        <Avatar className="h-12 w-12 border-2 border-white shadow-sm">
          <AvatarImage src="https://github.com/shadcn.png" />
          <AvatarFallback>LA</AvatarFallback>
        </Avatar>
      </div>
      
      {/* Offline Status indicator mocked */}
      <div className="bg-emerald-50 text-emerald-700 p-3 rounded-lg text-sm flex items-center font-medium border border-emerald-100 shadow-sm">
        <CheckCircle2 className="w-5 h-5 mr-2 text-emerald-500" />
        Đã đồng bộ trực tuyến
      </div>

      <div>
        <h2 className="text-lg font-bold mb-4 text-slate-800 flex items-center justify-between">
          Lịch của bạn (3)
          <span className="text-xs font-normal text-blue-600 bg-blue-50 px-2 py-1 rounded-full">Kín lịch</span>
        </h2>
        <div className="space-y-4">
          
          {/* Active Booking Card */}
          <Card className="border-blue-200 shadow-md ring-2 ring-blue-100 overflow-hidden transform transition-all">
            <div className="bg-blue-600 text-white text-xs font-bold px-4 py-1.5 uppercase tracking-wider flex items-center">
              <span className="w-2 h-2 rounded-full bg-white animate-pulse mr-2"></span>
              Đang thực hiện
            </div>
            <CardContent className="p-4">
              <div className="flex justify-between items-start mb-3">
                <div>
                  <h3 className="font-bold text-lg text-slate-900">Nguyễn Trần Vy</h3>
                  <p className="text-blue-600 font-medium text-sm mt-0.5">Gói Combo VIP 90&apos;</p>
                </div>
                <div className="text-right bg-slate-50 p-2 rounded-lg border border-slate-100">
                  <p className="font-bold text-xl text-slate-800">10:00</p>
                  <p className="text-xs text-slate-500">~ 11:30</p>
                </div>
              </div>
              
              <div className="flex items-start text-sm text-amber-800 mb-4 bg-amber-50 p-3 rounded-md border border-amber-100">
                <AlertCircle className="w-5 h-5 mr-2 text-amber-500 shrink-0 mt-0.5" />
                <span className="leading-snug text-xs font-medium">Lưu ý: Khách hay đau vai gáy, xoa bóp nhẹ tay phần cổ. Dị ứng tinh dầu tràm.</span>
              </div>
              
              <Button className="w-full bg-blue-600 hover:bg-blue-700 h-12 text-base font-bold shadow-sm">Hoàn thành dịch vụ</Button>
            </CardContent>
          </Card>

          {/* Pending Booking Card */}
          <Card className="border-slate-200 shadow-sm opacity-90 hover:opacity-100 transition-opacity">
            <CardContent className="p-4">
              <div className="flex justify-between items-start mb-3">
                <div>
                  <h3 className="font-semibold text-slate-900">Trần Lê Huy</h3>
                  <p className="text-slate-600 text-sm mt-0.5">Massage Body Đá Nóng (60p)</p>
                </div>
                <div className="text-right">
                  <p className="font-bold text-lg text-slate-700">13:30</p>
                </div>
              </div>
              <Button variant="outline" className="w-full border-blue-200 text-blue-700 hover:bg-blue-50 h-10 font-medium">Bắt đầu ngay</Button>
            </CardContent>
          </Card>

           {/* Pending Booking Card 2 */}
           <Card className="border-slate-200 shadow-sm opacity-90 hover:opacity-100 transition-opacity">
            <CardContent className="p-4">
              <div className="flex justify-between items-start mb-3">
                <div>
                  <h3 className="font-semibold text-slate-900">Khách vãng lai</h3>
                  <p className="text-slate-600 text-sm mt-0.5">Gội đầu dưỡng sinh (45p)</p>
                </div>
                <div className="text-right">
                  <p className="font-bold text-lg text-slate-700">15:00</p>
                </div>
              </div>
              <Button variant="outline" className="w-full border-slate-300 text-slate-700 hover:bg-slate-50 h-10 font-medium">Bắt đầu ngay</Button>
            </CardContent>
          </Card>

        </div>
      </div>
    </div>
  );
}
