"use client";

import React from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Search, MoreHorizontal, ShoppingCart, CreditCard, UserPlus } from 'lucide-react';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

const customers = [
  { id: 1, name: 'Emma Watson', email: 'emma@example.com', phone: '+1 555 123 4567', spent: '$1,250', visits: 12, lastVisit: '2 days ago', status: 'VIP' },
  { id: 2, name: 'John Doe', email: 'john@example.com', phone: '+1 555 234 5678', spent: '$340', visits: 3, lastVisit: '1 month ago', status: 'Regular' },
  { id: 3, name: 'Sarah Connor', email: 'sarah@example.com', phone: '+1 555 345 6789', spent: '$890', visits: 8, lastVisit: '1 week ago', status: 'Regular' },
  { id: 4, name: 'Michael Scott', email: 'michael@example.com', phone: '+1 555 456 7890', spent: '$120', visits: 1, lastVisit: '3 months ago', status: 'New' },
];

export default function CustomersPage() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Customers</h1>
          <p className="text-muted-foreground mt-1">Manage your clients and process checkouts.</p>
        </div>
        <Button>
          <UserPlus className="mr-2 h-4 w-4" /> Add Customer
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Customer Directory</CardTitle>
          <CardDescription>A complete list of your clients.</CardDescription>
          <div className="flex items-center pt-4 justify-between">
            <div className="relative flex-1 max-w-sm">
              <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
              <Input type="search" placeholder="Search customers..." className="pl-8" />
            </div>
            <div className="flex items-center gap-2">
              <Button variant="outline">Export CSV</Button>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Customer</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Total Spent</TableHead>
                <TableHead>Total Visits</TableHead>
                <TableHead>Last Visit</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {customers.map((customer) => (
                <TableRow key={customer.id}>
                  <TableCell className="flex items-center gap-3">
                    <Avatar className="h-9 w-9">
                      <AvatarFallback>{customer.name.split(' ').map(n => n[0]).join('')}</AvatarFallback>
                    </Avatar>
                    <div>
                      <div className="font-medium">{customer.name}</div>
                      <div className="text-sm text-muted-foreground">{customer.email}</div>
                    </div>
                  </TableCell>
                  <TableCell>
                    <Badge variant={customer.status === 'VIP' ? 'default' : (customer.status === 'New' ? 'secondary' : 'outline')}>
                      {customer.status}
                    </Badge>
                  </TableCell>
                  <TableCell className="font-medium">{customer.spent}</TableCell>
                  <TableCell>{customer.visits}</TableCell>
                  <TableCell>{customer.lastVisit}</TableCell>
                  <TableCell className="text-right">
                    <div className="flex items-center justify-end gap-2">
                      <Dialog>
                        <DialogTrigger render={
                          <Button variant="secondary" size="sm">
                            <ShoppingCart className="mr-2 h-4 w-4" /> Checkout
                          </Button>
                        } />
                        <DialogContent className="sm:max-w-[425px]">
                          <DialogHeader>
                            <DialogTitle>New Transaction</DialogTitle>
                            <DialogDescription>
                              Process a payment for {customer.name}.
                            </DialogDescription>
                          </DialogHeader>
                          <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                              <label className="text-sm font-medium">Service / Product</label>
                              <Select>
                                <SelectTrigger>
                                  <SelectValue placeholder="Select service..." />
                                </SelectTrigger>
                                <SelectContent>
                                  <SelectItem value="massage">Deep Tissue Massage ($120)</SelectItem>
                                  <SelectItem value="facial">Hydrating Facial ($90)</SelectItem>
                                  <SelectItem value="nails">Manicure & Pedicure ($60)</SelectItem>
                                </SelectContent>
                              </Select>
                            </div>
                            <div className="grid gap-2">
                              <label className="text-sm font-medium">Amount</label>
                              <Input type="text" defaultValue="$120.00" disabled />
                            </div>
                            <div className="grid gap-2">
                              <label className="text-sm font-medium">Payment Method</label>
                              <Select>
                                <SelectTrigger>
                                  <SelectValue placeholder="Select method..." />
                                </SelectTrigger>
                                <SelectContent>
                                  <SelectItem value="card">Credit Card</SelectItem>
                                  <SelectItem value="cash">Cash</SelectItem>
                                  <SelectItem value="gift">Gift Card</SelectItem>
                                </SelectContent>
                              </Select>
                            </div>
                          </div>
                          <DialogFooter>
                            <Button type="submit"><CreditCard className="mr-2 h-4 w-4" /> Process Payment</Button>
                          </DialogFooter>
                        </DialogContent>
                      </Dialog>

                      <DropdownMenu>
                        <DropdownMenuTrigger render={
                          <Button variant="ghost" className="h-8 w-8 p-0">
                            <MoreHorizontal className="h-4 w-4" />
                          </Button>
                        } />
                        <DropdownMenuContent align="end">
                          <DropdownMenuLabel>Actions</DropdownMenuLabel>
                          <DropdownMenuItem>View Profile</DropdownMenuItem>
                          <DropdownMenuItem>View History</DropdownMenuItem>
                          <DropdownMenuItem>Edit Details</DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
