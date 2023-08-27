#!/usr/bin/env python3

from enum import Enum

class cmkstatus(Enum):
    OK          = 0
    WARN        = 1
    CRIT        = 2
    UNKNOWN     = 3
    CALCULATED  = 'P'

    def __str__(self) -> str:
        return str(self.value)

class cmkservice(object):
    def __init__(self, direct_called=True, **kwargs):
        if direct_called:
            raise ValueError
        self.__dict__.update(kwargs)
        # for key in kwargs:
        #     setattr(self, key, kwargs[key])

    def __get_metric_string(self):
        metric_string = '{}={}'.format(self.metric_name, self.metric_value)
        if hasattr(self,'metric_warn'):
            metric_string =  '{}={};{};{};{};{}'.format(self.metric_name, self.metric_value, self.metric_warn, self.metric_crit, self.metric_min, self.metric_max)
        return metric_string
    @classmethod
    def simple(cls, state:cmkstatus, service:str, detail:str):
        return cls(direct_called=False, state=state, service=service, detail=detail)

    @classmethod
    def with_metric(cls, state:cmkstatus, service:str, detail:str, metric_name:str, metric_value:int):
        return cls(direct_called=False, state=state, service=service,
                   detail=detail, metric_name=metric_name, metric_value=metric_value)

    @classmethod
    def with_threshold(cls, service:str, detail:str, metric_name:str, metric_value:int, metric_warn:int, metric_crit:int, metric_min:int, metric_max:int):
        return cls(direct_called=False, state='P', service=service,
                   detail=detail, metric_name=metric_name, metric_value=metric_value,
                   metric_warn=metric_warn, metric_crit=metric_crit, metric_min=metric_min, metric_max=metric_max)

    def __str__(self) -> str:
        if hasattr(self, 'metric_name'):
            return f'{ self.state } "{ self.service }" { self.__get_metric_string() } { self.detail }'

        return f'{self.state} "{ self.service }" - { self.detail }'