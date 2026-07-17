"use client";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Plus, Users, Clock, Briefcase } from 'lucide-react';
import { useState } from 'react';

export function BookingSheet({ children }: { children: React.ReactElement }) {
  const [open, setOpen] = useState(false);

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger render={children} />
      <SheetContent className="w-full sm:max-w-md overflow-y-auto bg-slate-50 border-l border-slate-200 shadow-2xl">
        <SheetHeader className="mb-6 pb-4 border-b border-slate-200">
          <SheetTitle className="text-xl font-bold text-slate-900 flex items-center">
            <Plus className="w-5 h-5 mr-2 text-blue-600" /> Tạo Lịch Hẹn Mới
          </SheetTitle>
        </SheetHeader>
        
        <div className="space-y-6">
          {/* Customer */}
          <div className="space-y-2">
            <label className="text-sm font-semibold text-slate-700 flex items-center"><Users className="w-4 h-4 mr-1 text-slate-400"/> Khách hàng</label>
            <div className="flex gap-2">
              <Input placeholder="Nhập SDT hoặc Tên..." className="flex-1 bg-white" />
              <Button variant="outline" className="shrink-0 bg-white shadow-sm" title="Thêm khách hàng mới"><Plus className="w-4 h-4" /></Button>
            </div>
            <p className="text-[11px] text-slate-500 italic">* Chạy Debounced Server-side Search</p>
          </div>

          {/* Service */}
          <div className="space-y-2">
            <label className="text-sm font-semibold text-slate-700 flex items-center"><Briefcase className="w-4 h-4 mr-1 text-slate-400"/> Dịch vụ</label>
            <Select>
              <SelectTrigger className="bg-white">
                <SelectValue placeholder="Chọn dịch vụ" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="s1">Massage Body 60p</SelectItem>
                <SelectItem value="s2">Gội đầu dưỡng sinh</SelectItem>
                <SelectItem value="s3">Chăm sóc da mặt cơ bản</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Therapist */}
          <div className="space-y-2">
            <label className="text-sm font-semibold text-slate-700 flex items-center"><Users className="w-4 h-4 mr-1 text-slate-400"/> Nhân viên (Thợ)</label>
            <Select>
              <SelectTrigger className="bg-white">
                <SelectValue placeholder="Chọn nhân viên" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="t1">Lan Anh - Khuyên chọn</SelectItem>
                <SelectItem value="t2">Minh Tú</SelectItem>
                <SelectItem value="t3">Ngọc Hân</SelectItem>
              </SelectContent>
            </Select>
            <p className="text-[11px] text-slate-500 italic">* Gợi ý tức thì từ Deterministic SQL Rules</p>
          </div>

          {/* Time */}
          <div className="space-y-2">
            <label className="text-sm font-semibold text-slate-700 flex items-center"><Clock className="w-4 h-4 mr-1 text-slate-400"/> Thời gian (Hôm nay)</label>
            <div className="grid grid-cols-2 gap-3">
              <Select>
                <SelectTrigger className="bg-white"><SelectValue placeholder="Giờ" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="14:00">14:00</SelectItem>
                  <SelectItem value="14:30">14:30</SelectItem>
                  <SelectItem value="15:00">15:00</SelectItem>
                </SelectContent>
              </Select>
              <div className="flex items-center justify-center bg-slate-100 text-slate-500 text-sm rounded-md border border-slate-200">
                ~ 15:30 (90p)
              </div>
            </div>
          </div>
          
          <div className="pt-6 mt-4 border-t border-slate-200">
            <Button className="w-full bg-blue-600 hover:bg-blue-700 text-base py-6 shadow-md" onClick={() => setOpen(false)}>Hoàn tất Đặt lịch</Button>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
