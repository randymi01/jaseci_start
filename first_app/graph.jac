node state {
    has title;
    has message;
    has prompts;
}


edge transition {
    has intent;
}

graph main_graph {
    has anchor main_root;

    spawn {
    # it doesn't work
    main_root = spawn node::state(
        title = "Welcome",
        message = "Welcome to Jaseci Dojo, how can i help?",
        prompts = ["class","times","prices","quit"]
    );

    prices = spawn main_root -[transition(intent="prices")] -> node::state(
        title = "prices",
        message = "Prices Vary based on age",
        prompts = ["12 and younger", "18 and younger" ,"Older than 18", "quit"]
    );

    }
}