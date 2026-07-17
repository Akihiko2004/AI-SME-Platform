import { BookingSheet } from '@/components/admin/BookingSheet';
import { Button } from '@/components/ui/button';
import { ChevronLeft, ChevronRight, Plus } from 'lucide-react';

export default function CalendarPage() {
  const timeSlots = ["09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00", "16:00", "17:00"];
  const staff = ["Lan Anh", "Minh Tú", "Ngọc Hân"];

  return (
    <div className="h-full flex flex-col bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden min-h-[600px]">
      <div className="flex items-center justify-between p-4 md:p-6 border-b border-slate-100 bg-slate-50/50">
        <div className="flex items-center gap-4">
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Lịch Hẹn</h1>
          <div className="flex items-center bg-white rounded-lg p-1 border border-slate-200 shadow-sm">
            <button className="p-1 hover:bg-slate-50 rounded-md text-slate-500 hover:text-slate-900 transition-colors"><ChevronLeft size={20} /></button>
            <span className="px-4 font-semibold text-sm text-slate-700">Hôm nay, 12 Thg 10</span>
            <button className="p-1 hover:bg-slate-50 rounded-md text-slate-500 hover:text-slate-900 transition-colors"><ChevronRight size={20} /></button>
          </div>
        </div>
        
        <BookingSheet>
          <Button className="bg-blue-600 hover:bg-blue-700 font-medium shadow-sm"><Plus className="w-4 h-4 mr-2" /> Tạo lịch mới</Button>
        </BookingSheet>
      </div>

      <div className="flex-1 overflow-auto bg-slate-50/30 p-4 lg:p-6">
        {/* Mock Calendar Grid */}
        <div className="min-w-[800px] max-w-5xl mx-auto border border-slate-200 rounded-xl bg-white overflow-hidden shadow-sm">
          {/* Header Row */}
          <div className="flex border-b border-slate-200 bg-slate-100/80">
            <div className="w-20 shrink-0 border-r border-slate-200 flex items-center justify-center py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">
              Giờ
            </div>
            {staff.map((name, i) => (
              <div key={i} className="flex-1 border-r border-slate-200 last:border-0 py-3 text-center font-bold text-slate-800 text-sm">
                {name}
              </div>
            ))}
          </div>
          
          {/* Grid Rows */}
          <div className="relative">
             {timeSlots.map((time, i) => (
                <div key={i} className="flex border-b border-slate-100 last:border-0 relative h-24 group">
                  <div className="w-20 shrink-0 border-r border-slate-200 flex justify-center pt-2 text-xs font-medium text-slate-400 bg-slate-50/50">
                    {time}
                  </div>
                  {staff.map((name, j) => (
                    <div key={j} className="flex-1 border-r border-slate-100 last:border-0 hover:bg-blue-50/30 transition-colors cursor-crosshair">
                      {/* Empty cell */}
                    </div>
                  ))}
                </div>
             ))}

             {/* Mock Bookings Overlay */}
             <div className="absolute top-[24px] left-[80px] right-0 bottom-0 pointer-events-none flex">
                <div className="flex-1 relative">
                  {/* Booking 1 */}
                  <div className="absolute top-[10px] left-2 right-2 h-[80px] bg-blue-50 border-l-4 border-blue-500 rounded-r-md p-2 shadow-sm pointer-events-auto cursor-pointer hover:bg-blue-100 hover:shadow-md transition-all group">
                    <p className="text-xs font-bold text-slate-800">Nguyễn Trần Vy <span className="bg-amber-100 text-amber-800 px-1 py-0.5 rounded text-[9px] ml-1">VIP</span></p>
                    <p className="text-[10px] text-slate-500 mt-1 font-medium">Combo VIP 90&apos;</p>
                    <div className="absolute top-2 right-2 w-2 h-2 rounded-full bg-blue-500 animate-pulse"></div>
                  </div>
                </div>
                <div className="flex-1 relative">
                  {/* Booking 2 */}
                  <div className="absolute top-[90px] left-2 right-2 h-[60px] bg-amber-50 border-l-4 border-amber-500 rounded-r-md p-2 shadow-sm pointer-events-auto cursor-pointer hover:bg-amber-100 hover:shadow-md transition-all">
                    <p className="text-xs font-bold text-slate-800">Trần Lê Huy</p>
                    <p className="text-[10px] text-slate-500 mt-1 font-medium">Massage 60&apos;</p>
                  </div>
                </div>
                <div className="flex-1 relative">
                   {/* Booking 3 */}
                   <div className="absolute top-[180px] left-2 right-2 h-[45px] bg-slate-50 border-l-4 border-slate-400 rounded-r-md p-2 shadow-sm pointer-events-auto cursor-pointer hover:bg-slate-100 transition-all">
                    <p className="text-xs font-bold text-slate-800">Khách vãng lai</p>
                    <p className="text-[10px] text-slate-500 mt-0.5 font-medium">Gội đầu 45&apos;</p>
                  </div>
                </div>
             </div>
          </div>
        </div>
      </div>
    </div>
  );
}
