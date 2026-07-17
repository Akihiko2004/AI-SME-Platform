"use client";

import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Store, User, Bell, Shield, CreditCard } from 'lucide-react';

export default function SettingsPage() {
  const [activeTab, setActiveTab] = useState('general');

  const tabs = [
    { id: 'general', label: 'General', icon: Store },
    { id: 'profile', label: 'Profile', icon: User },
    { id: 'notifications', label: 'Notifications', icon: Bell },
    { id: 'security', label: 'Security', icon: Shield },
    { id: 'billing', label: 'Billing', icon: CreditCard },
  ];

  return (
    <div className="flex flex-col gap-6 max-w-6xl mx-auto w-full">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Settings</h1>
        <p className="text-muted-foreground mt-1">Manage your spa preferences and account settings.</p>
      </div>

      <div className="flex flex-col md:flex-row gap-8">
        {/* Sidebar */}
        <div className="flex flex-col gap-2 w-full md:w-64 shrink-0">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            return (
              <Button
                key={tab.id}
                variant={activeTab === tab.id ? 'secondary' : 'ghost'}
                className="justify-start w-full"
                onClick={() => setActiveTab(tab.id)}
              >
                <Icon className="mr-2 h-4 w-4" /> {tab.label}
              </Button>
            );
          })}
        </div>

        {/* Content */}
        <div className="flex-1">
          {activeTab === 'general' && (
            <Card>
              <CardHeader>
                <CardTitle>General Settings</CardTitle>
                <CardDescription>Update your spa&apos;s business information.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid gap-2">
                  <label className="text-sm font-medium">Business Name</label>
                  <Input defaultValue="Serenity Spa & Wellness" />
                </div>
                <div className="grid gap-2">
                  <label className="text-sm font-medium">Contact Email</label>
                  <Input type="email" defaultValue="hello@serenityspa.com" />
                </div>
                <div className="grid gap-2">
                  <label className="text-sm font-medium">Phone Number</label>
                  <Input type="tel" defaultValue="(555) 123-4567" />
                </div>
                <div className="grid gap-2">
                  <label className="text-sm font-medium">Address</label>
                  <Input defaultValue="123 Wellness Blvd, Health City, HC 12345" />
                </div>
              </CardContent>
              <CardFooter>
                <Button>Save Changes</Button>
              </CardFooter>
            </Card>
          )}

          {activeTab === 'profile' && (
            <Card>
              <CardHeader>
                <CardTitle>Admin Profile</CardTitle>
                <CardDescription>Manage your personal administrator details.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center gap-4 mb-4">
                  <div className="h-20 w-20 rounded-full bg-slate-200 flex items-center justify-center text-xl font-bold text-slate-500">
                    AD
                  </div>
                  <Button variant="outline">Change Avatar</Button>
                </div>
                <div className="grid gap-2">
                  <label className="text-sm font-medium">Full Name</label>
                  <Input defaultValue="Admin User" />
                </div>
                <div className="grid gap-2">
                  <label className="text-sm font-medium">Email Address</label>
                  <Input type="email" defaultValue="admin@serenityspa.com" />
                </div>
              </CardContent>
              <CardFooter>
                <Button>Update Profile</Button>
              </CardFooter>
            </Card>
          )}

          {/* Fallback for other tabs */}
          {['notifications', 'security', 'billing'].includes(activeTab) && (
            <Card>
              <CardHeader>
                <CardTitle className="capitalize">{activeTab} Settings</CardTitle>
                <CardDescription>Configure your {activeTab} preferences.</CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-slate-500">This section is currently under development.</p>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}
