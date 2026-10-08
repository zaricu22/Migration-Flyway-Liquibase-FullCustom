UPDATE orders SET status = 'cancelled' WHERE status = 'new' AND id % 10 = 0;
