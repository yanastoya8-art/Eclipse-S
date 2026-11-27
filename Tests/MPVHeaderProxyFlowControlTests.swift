    func cancel() {
        // Close the client socket before the test starts waiting for the proxy
        // to observe downstream cancellation. An asynchronous enqueue here
        // allowed the test thread to race its own cancellation assertion.
        queue.sync { self.finish(error: "cancelled") }
    }