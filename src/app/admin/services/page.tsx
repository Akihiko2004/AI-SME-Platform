"use client";

import React from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Search, Plus, Clock, DollarSign, MoreVertical, Edit, Trash2 } from 'lucide-react';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';

const services = [
  { id: 1, name: 'Swedish Massage', category: 'Massage', duration: '60 min', price: '$90', status: 'Active', description: 'A gentle, relaxing full-body massage.' },
  { id: 2, name: 'Deep Tissue Massage', category: 'Massage', duration: '90 min', price: '$140', status: 'Active', description: 'Targets deeper layers of muscle and connective tissue.' },
  { id: 3, name: 'Hydrating Facial', category: 'Skincare', duration: '45 min', price: '$85', status: 'Active', description: 'Restores moisture and glow to the skin.' },
  { id: 4, name: 'Anti-Aging Facial', category: 'Skincare', duration: '60 min', price: '$120', status: 'Active', description: 'Advanced techniques to reduce signs of aging.' },
  { id: 5, name: 'Deluxe Pedicure', category: 'Nails', duration: '45 min', price: '$55', status: 'Active', description: 'Includes foot soak, scrub, mask, and massage.' },
  { id: 6, name: 'Hot Stone Therapy', category: 'Massage', duration: '75 min', price: '$130', status: 'Inactive', description: 'Uses smooth, heated stones for deep relaxation.' },
];

export default function ServicesPage() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Services Menu</h1>
          <p className="text-muted-foreground mt-1">Manage your service offerings, prices, and durations.</p>
        </div>
        <Button>
          <Plus className="mr-2 h-4 w-4" /> Add Service
        </Button>
      </div>

      <div className="flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="relative flex-1 w-full max-w-md">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input type="search" placeholder="Search services..." className="pl-8" />
        </div>
        <div className="flex gap-2 w-full md:w-auto overflow-x-auto pb-2 md:pb-0">
          <Button variant="secondary">All</Button>
          <Button variant="ghost">Massage</Button>
          <Button variant="ghost">Skincare</Button>
          <Button variant="ghost">Nails</Button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {services.map((service) => (
          <Card key={service.id} className="flex flex-col">
            <CardHeader className="pb-4 flex-row items-start justify-between">
              <div>
                <CardTitle className="text-xl">{service.name}</CardTitle>
                <CardDescription className="mt-1">{service.category}</CardDescription>
              </div>
              <DropdownMenu>
                <DropdownMenuTrigger render={
                  <Button variant="ghost" className="h-8 w-8 p-0">
                    <MoreVertical className="h-4 w-4" />
                  </Button>
                } />
                <DropdownMenuContent align="end">
                  <DropdownMenuItem>
                    <Edit className="mr-2 h-4 w-4" /> Edit Service
                  </DropdownMenuItem>
                  <DropdownMenuItem className="text-red-600">
                    <Trash2 className="mr-2 h-4 w-4" /> Delete
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </CardHeader>
            <CardContent className="flex-1">
              <p className="text-sm text-slate-600 mb-4">{service.description}</p>
              <div className="flex items-center gap-4 text-sm text-slate-700">
                <div className="flex items-center">
                  <Clock className="mr-1 h-4 w-4 text-slate-400" />
                  {service.duration}
                </div>
                <div className="flex items-center font-medium">
                  <DollarSign className="mr-1 h-4 w-4 text-slate-400" />
                  {service.price}
                </div>
              </div>
            </CardContent>
            <CardFooter className="pt-4 border-t border-slate-100 flex justify-between items-center">
              <Badge variant={service.status === 'Active' ? 'default' : 'secondary'}>
                {service.status}
              </Badge>
              <Button variant="outline" size="sm">Edit Prices</Button>
            </CardFooter>
          </Card>
        ))}
      </div>
    </div>
  );
}
