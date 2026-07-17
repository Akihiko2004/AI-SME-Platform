"use client";

import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Search, Plus, MoreHorizontal, Clock, Calendar as CalendarIcon, UserCheck } from 'lucide-react';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';

const employees = [
  { id: 1, name: 'Alice Nguyen', role: 'Senior Therapist', status: 'Active', email: 'alice@example.com', phone: '+1 234 567 8900' },
  { id: 2, name: 'Bob Smith', role: 'Massage Therapist', status: 'On Leave', email: 'bob@example.com', phone: '+1 234 567 8901' },
  { id: 3, name: 'Carol Danvers', role: 'Receptionist', status: 'Active', email: 'carol@example.com', phone: '+1 234 567 8902' },
  { id: 4, name: 'David Lee', role: 'Esthetician', status: 'Active', email: 'david@example.com', phone: '+1 234 567 8903' },
];

export default function EmployeesPage() {
  const [activeTab, setActiveTab] = useState<'directory' | 'shifts' | 'time'>('directory');

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">HR Management</h1>
          <p className="text-muted-foreground mt-1">Manage your staff, schedules, and time tracking.</p>
        </div>
        <Button>
          <Plus className="mr-2 h-4 w-4" /> Add Employee
        </Button>
      </div>

      <div className="flex items-center space-x-2 border-b pb-4">
        <Button variant={activeTab === 'directory' ? 'default' : 'ghost'} onClick={() => setActiveTab('directory')}>
          <UserCheck className="mr-2 h-4 w-4" /> Directory
        </Button>
        <Button variant={activeTab === 'shifts' ? 'default' : 'ghost'} onClick={() => setActiveTab('shifts')}>
          <CalendarIcon className="mr-2 h-4 w-4" /> Shifts
        </Button>
        <Button variant={activeTab === 'time' ? 'default' : 'ghost'} onClick={() => setActiveTab('time')}>
          <Clock className="mr-2 h-4 w-4" /> Time Tracking
        </Button>
      </div>

      {activeTab === 'directory' && (
        <Card>
          <CardHeader>
            <CardTitle>Employee Directory</CardTitle>
            <CardDescription>A list of all employees in your spa.</CardDescription>
            <div className="flex items-center pt-4">
              <div className="relative flex-1 max-w-sm">
                <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
                <Input type="search" placeholder="Search employees..." className="pl-8" />
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Employee</TableHead>
                  <TableHead>Role</TableHead>
                  <TableHead>Contact</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {employees.map((employee) => (
                  <TableRow key={employee.id}>
                    <TableCell className="flex items-center gap-3">
                      <Avatar className="h-9 w-9">
                        <AvatarFallback>{employee.name.split(' ').map(n => n[0]).join('')}</AvatarFallback>
                      </Avatar>
                      <div>
                        <div className="font-medium">{employee.name}</div>
                        <div className="text-sm text-muted-foreground">{employee.email}</div>
                      </div>
                    </TableCell>
                    <TableCell>{employee.role}</TableCell>
                    <TableCell>{employee.phone}</TableCell>
                    <TableCell>
                      <Badge variant={employee.status === 'Active' ? 'default' : 'secondary'}>
                        {employee.status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      <DropdownMenu>
                        <DropdownMenuTrigger render={
                          <Button variant="ghost" className="h-8 w-8 p-0">
                            <MoreHorizontal className="h-4 w-4" />
                          </Button>
                        } />
                        <DropdownMenuContent align="end">
                          <DropdownMenuLabel>Actions</DropdownMenuLabel>
                          <DropdownMenuItem>View Profile</DropdownMenuItem>
                          <DropdownMenuItem>Edit Details</DropdownMenuItem>
                          <DropdownMenuItem className="text-red-600">Deactivate</DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}

      {activeTab === 'shifts' && (
        <Card>
          <CardHeader>
            <CardTitle>Upcoming Shifts</CardTitle>
            <CardDescription>View and manage staff schedules for the week.</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="h-[400px] flex items-center justify-center border border-dashed rounded-lg bg-slate-50">
              <div className="text-center">
                <CalendarIcon className="mx-auto h-8 w-8 text-muted-foreground mb-2" />
                <p className="text-muted-foreground">Shift calendar visualization would go here.</p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {activeTab === 'time' && (
        <Card>
          <CardHeader>
            <CardTitle>Time Tracking</CardTitle>
            <CardDescription>Recent clock-ins and clock-outs.</CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Employee</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead>Clock In</TableHead>
                  <TableHead>Clock Out</TableHead>
                  <TableHead>Total Hours</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                <TableRow>
                  <TableCell className="font-medium">Alice Nguyen</TableCell>
                  <TableCell>Oct 24, 2026</TableCell>
                  <TableCell>08:00 AM</TableCell>
                  <TableCell>04:00 PM</TableCell>
                  <TableCell>8h 0m</TableCell>
                </TableRow>
                <TableRow>
                  <TableCell className="font-medium">Bob Smith</TableCell>
                  <TableCell>Oct 24, 2026</TableCell>
                  <TableCell>09:30 AM</TableCell>
                  <TableCell>05:30 PM</TableCell>
                  <TableCell>8h 0m</TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
