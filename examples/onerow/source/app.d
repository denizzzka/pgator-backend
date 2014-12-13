// Written in D programming language
/**
*   Copyright: © 2014 DSoftOut
*   License: Subject to the terms of the MIT license, as written in the included LICENSE file.
*   Authors: NCrashed <ncrashed@gmail.com>
*/
module app;

import std.getopt;
import std.stdio;
import std.datetime;
import dlogg.strict;
import pgator.db.pq.libpq;
import pgator.db.pq.connection;
import pgator.db.async.pool;    

void main(string[] args)
{
    string logName = "app.log";
    string connString = "port=5432";
    bool help = false;
    
    args.getopt("l|log", &logName,
                "c|conn", &connString,
                "h|help", &help
                );
    
    if(help)
    {
        writeln("pgator-backend-example-onerow [options]\n\n",
          "\t-l|--log=path\t - path to log, default 'app.log'\n",
          "\t-c|--conn=string - connection string to PostgreSQL\n",
          "\t-h|--help\t - prints this message"
        );
        return;
    }
    
    // Initializing concurrent logger
    auto logger = new shared StrictLogger(logName);
    scope(exit) logger.finalize();

    // Intitializing PostgreSQL bindings and Connection factory
    auto api = new shared PostgreSQL(logger);
    auto connProvider = new shared PQConnProvider(logger, api);

    // Creating pool
    auto pool = new shared AsyncPool(logger, connProvider
        , dur!"seconds"(1) // time between reconnection tries
        , dur!"seconds"(5) // maximum time to wait for free connection appearing in the pool while quering
        , dur!"seconds"(3) // every 3 seconds check connection
        );
    scope(failure) pool.finalize();

    // Adding server to the pool
    pool.addServer(connString, 1);

    // Quering a server from pool
    auto bsonRange = pool.execTransaction(["select 10 as field"],
                                          [], // no parameters
                                          [], // no parameters
                                          null, // no vars
                                          [true] // indicates that first query should be one-row query
                                          );
    foreach(bson; bsonRange) writeln(bson);
    
    // Invalid query with rollback
    auto bsonRange2 = pool.execTransaction(["select 10 as field union select 11 as field"],
                                          [], // no parameters
                                          [], // no parameters
                                          null, // no vars
                                          [true] // indicates that first query should be one-row query
                                          );
    foreach(bson; bsonRange2) writeln(bson);
}